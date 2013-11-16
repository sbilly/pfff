(* Yoann Padioleau
 *
 * Copyright (C) 2012, 2013 Facebook
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
open Common

open Ast_php_simple
module Ast = Ast_php_simple
module E = Database_code
module G = Graph_code

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(*
 * Graph of dependencies for PHP. See graph_code.ml and main_codegraph.ml
 * for more information. Yet another code database for PHP ...
 *
 * See also old/graph_php.ml, facebook/flib_dependencies/,
 * and facebook/check_module/graph_module.ml
 *
 * schema:
 *  Root -> Dir -> File (.php) -> Class (used for interfaces and traits too)
 *                                 -> Method
 *                                 -> Field
 *                                 -> ClassConstant
 *                             -> Function
 *                             -> Constant
 *       -> Dir -> SubDir -> File -> ...
 *
 * less:
 *  - handle static vs non static methods/fields? but at the same time
 *    lots of our code abuse $this-> where they should use self::, so
 *    maybe simpler not make difference between static and non static
 *  - reuse env, most of of build() and put it in graph_code.ml
 *    and just pass the PHP specificities.
 *  - add tests
 *
 * issues regarding errors in a codebase and how to handle them:
 *  - parse errors, maybe test code?
 *    => skip list, file: or dir:
 *  - nested functions, duped functions defined conditionnally
 *    => use the at_toplevel field below
 *  - duped functions
 *    => skip list (or remove the offending code), file: or dir:
 *  - duped local functions in scripts/
 *    => skip list, skip_errors_dir:
 *  - lookup failure because use different software stack (e.g.
 *    html/intern/wiki/, lib/arcanist/, etc)
 *    => skip list, dir:
 *
 * where to display the errors:
 *  - terminal for the really important one
 *  - pfff.log for less important and to have more details
 *  - in the codegraph itself under the PB directory for all the rest
 *    when add_fake_node_when_undefined_entity is set to true.
 *  - in a layer, see layer_graph_code.ml, for errors but also statistics
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

type env = {
  g: Graph_code.graph;

  cur: current;

  phase: phase;
  (* We need 3 phases, one to get all the definitions, one to
   * get the inheritance information, and one to get all the Uses.
   * The inheritance is a kind of use, but certain uses like using
   * a field or method need the full inheritance tree to already be
   * computed as we may need to lookup entities up in the parents.
   *)
  phase_inheritance: (current * (Ast.name * E.entity_kind)) list ref;
  phase_use:         (current * (Ast.name * E.entity_kind)) list ref;
  phase_use_lookup:  
    (current * (bool * (Ast.name * Ast.ident) * E.entity_kind)) list ref;
  phase_use_other:         (unit -> unit) list ref;

  (* right now used in extract_uses phase to transform a src like main()
   * into its File, and also to give better error messages.
   * We use the Hashtbl.find_all property of the hashtbl below.
   * The pair of filenames is readable * fullpath
   *)
  dupes: (Graph_code.node, (Common.filename * Common.filename)) Hashtbl.t;
  (* to optimize things, to avoid calling G.Parent *)
  not_found: (Graph_code.node, bool) Hashtbl.t;

  (* in many files like scripts/ people reuse the same function name. This
   * is annoying for global analysis, so when we detect such files,
   * because right now they are listed in the skip file as skip_errors_dir:,
   * then we dynamically and locally rename this function.
   *)
  (* less: dupe_renaming *)

  (* PHP is case insensitive so certain lookup fails because people
   * used the wrong case. Those errors are less important so
   * we just automatically relookup to the correct entity.
   *)
  case_insensitive: (Graph_code.node, Graph_code.node) Hashtbl.t;

  stats: Graph_code.statistics;

  log: string -> unit;
  pr2_and_log: string -> unit;
  is_skip_error_file: Common.filename (* readable *) -> bool;
  (* to print file paths in readable format or absolute *)
  path: Common.filename -> string;
}
 and phase = Defs | Inheritance | Uses

 and current = {
   node: Graph_code.node;
   qualifier: Ast_php_simple.qualified_ident;
   readable: Common.filename;
   import_rules: (string * Ast_php_simple.qualified_ident) list;
   self:   string;                (* "NOSELF" when outside a class *)
   parent: unit -> resolved_name; (* "NOPARENT" when no parent *)
   at_toplevel: bool;
 }

 (* for namespace *)
 and resolved_name = R of string

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)
let (==~) = Common2.(==~)

let parse env file =
  try
    Common.save_excursion Ast_php_simple_build.store_position true (fun () ->
    Common.save_excursion Flag_parsing_php.strict_lexer true (fun () ->
    let cst = Parse_php.parse_program file in
    let ast = Ast_php_simple_build.program cst in
    ast
    ))
  with
  | Timeout -> raise Timeout
  | exn ->
     env.stats.G.parse_errors +> Common.push2 file;
     env.pr2_and_log (spf "PARSE ERROR with %s, exn = %s" (env.path file)
                        (Common.exn_to_s exn));
     []
      
  
let xhp_field str = 
  (str =~ ".*=")
let addpostfix = function
  | (str, tok) -> (str ^ "=", tok)

(* Ignore certain xhp fields, custom data attribute:
 * http://www.w3.org/TR/2011/WD-html5-20110525/elements.html,
 * #embedding-custom-non-visible-data-with-the-data-attributes ARIA: 
 * http://dev.w3.org/html5/markup/aria/aria.html,
 * server side attribute: flib/markup/xhp/html.php:52 *)
let xhp_data_field str =
  (str =~ ".*\\.\\(data\\|aria\\|srvr\\)-.*=")

(* todo: handle __call and the dynamicYield idiom instead of this whitelist *)
let magic_methods str =
 (* facebook specific, dynamicYield *)
 str =~ ".*\\.gen.*" || str =~ ".*\\.get.*" || str =~ ".*\\.prepare.*" ||
 (* phabricator LiskDAO *)
 str =~ ".*\\.set[A-Z].*"

(* In PHP people abuse strings to pass classnames or function names.
 * We want to add use edges for those cases but we need some heuristics
 * to detect whether the string was really a classname or by coincidence
 * a regular word that happens to be also a classname.
 *)
let look_like_class_sure =
  Str.regexp "^\\([A-Z][A-Za-z_0-9]*\\)\\(::[A-Za-z_0-9]*\\)$"
let look_like_class_maybe =
  Str.regexp "^\\([A-Z][A-Za-z_0-9]*[A-Z][A-Za-z_0-9]*\\)$"

let look_like_class s =
  match s with
  | s when s ==~ look_like_class_sure -> true
  (* todo: too many fps in thrift code
   * | s when s ==~ look_like_class_maybe -> true
   *)
  | _ -> false

let privacy_of_modifiers modifiers =
  (* yes, default is public ... I love PHP *)
  let p = ref E.Public in
  modifiers +> List.iter (function
  | Ast_php.Public -> p := E.Public
  | Ast_php.Private -> p := E.Private
  | Ast_php.Protected -> p := E.Protected
  | _ -> ()
  );
  !p

let normalize str = 
  str
  +> String.lowercase                         (* php is case insensitive *)
  +> Str.global_replace (Str.regexp "-") "_"  (* xhp is "dash" insensitive *)

(*****************************************************************************)
(* Namespace *)
(*****************************************************************************)

(* todo: move to Ast_php_simple.name_of_class_name at some point *)
let (name_of_class_name: Ast.hint_type -> name) = fun x ->
  match x with
  | Hint name -> name
  | _ -> raise Common.Impossible

let add_prefix qu =
  match qu with
  | [] -> ""
  | x::xs -> ((x::xs) +> List.map Ast.str_of_ident +> Common.join "\\")^"\\"

let prune_special_root xs =
  match xs with
  | ("__special__ROOT", _)::xs -> xs
  | _ -> xs

(* http://www.php.net/manual/en/language.namespaces.rules.php *)
let fully_qualified_candidates cur name kind =
  match name with
  | [] -> raise Impossible
  | ("__special__ROOT",_)::xs -> 
      [xs]
  | ("__special__namespace",_)::xs ->
      failwith "namespace keyword not handled in qualifier"
  | (str, _tokopt)::xs  ->
    try 
      let qu = List.assoc str cur.import_rules in
      [ prune_special_root qu ++ xs ]
    with Not_found ->
      [name;
       cur.qualifier ++ name;
      ]
    

let (strtok_of_name: env -> Ast.name -> Database_code.entity_kind -> 
     resolved_name Ast.wrap) = 
 fun env name kind ->
   let tokopt =
     match name with
     | (ident, tokopt)::rest -> tokopt
     | [] -> raise Impossible
   in
   let candidates = fully_qualified_candidates env.cur name kind in
   try 
    candidates +> Common.find_some (fun fullname ->
     let str = fullname +> List.map Ast.str_of_ident +> Common.join "\\" in
     if G.has_node (str, kind) env.g
     then Some (R str, tokopt)
     else None
   )
   with Not_found ->
     let str = name +> List.map Ast.str_of_ident +> Common.join "\\" in
     R str, tokopt
     

let str_of_name env x kind =
  fst (strtok_of_name env x kind)

let (strtok_of_class_name: env -> Ast.hint_type -> resolved_name Ast.wrap) =
  fun env x ->
    let name = name_of_class_name x in
    strtok_of_name env name (E.Class E.RegularClass)

let str_of_class_name env x =
  fst (strtok_of_class_name env x)

let name_of_parent env tokopt =
  let name = 
    let (R parent) = env.cur.parent () in
    [parent, tokopt]
  in
  name

(*****************************************************************************)
(* Add node *)
(*****************************************************************************)
(* The flag below is useful to minimize the lookup failure errors.
 * 
 * It has some bad side effects though; in certain contexts,
 * such as scheck, you want to get all the errors and not just
 * the first lookup failure.
 *)
let add_fake_node_when_undefined_entity = ref true

let add_node_and_has_edge2 ?(props=[]) env (ident, kind) =
  let str =
    add_prefix env.cur.qualifier ^
    (match kind with
    | E.ClassConstant | E.Field | E.Method _ -> env.cur.self ^ "."
    | _ -> ""
    ) ^ 
    Ast.str_of_ident ident
  in
  let node = (str, kind) in
  begin
   if G.has_node node env.g
   then
    let file = Parse_info.file_of_info (Ast.tok_of_ident ident) in
    (* todo: look if is_skip_error_file in which case populate
     * a env.dupe_renaming
     *)
    (match kind with
    (* less: log at least? *)
    | E.Class _ | E.Function | E.Constant when not env.cur.at_toplevel -> ()

    (* If the class was dupe, of course all its members are also duped.
     * But actually we also need to add it to env.dupes, so below,
     * we dont set env.current to this node, otherwise we may
     * pollute the callees of the original node.
     *)
    | E.ClassConstant | E.Field | E.Method _
        when Hashtbl.mem env.dupes (env.cur.self, E.Class E.RegularClass) ->
          Hashtbl.add env.dupes node (env.cur.readable, file)
    | E.ClassConstant | E.Field | E.Method _ ->
        env.pr2_and_log (spf "DUPE METHOD: %s" (G.string_of_node node));
    | _ ->
        Hashtbl.add env.dupes node (env.cur.readable, file)
    )
   else begin
    env.g +> G.add_node node;
    (* if we later find a duplicate for node, we will
     * redirect this edge in build() to G.dupe (unless
     * the duplicate are all in a skip_errors dir).
     *)
    env.g +> G.add_edge (env.cur.node, node) G.Has;
    let pos = Parse_info.token_location_of_info (Ast.tok_of_ident ident) in
    let pos = { pos with Parse_info.file = env.cur.readable } in
    let nodeinfo = { Graph_code. pos; props } in
    env.g +> G.add_nodeinfo node nodeinfo;
   end
  end;
  (* for dupes like main(), but also dupe classes, or methods of dupe
   * classe, it's better to keep 'current' as the current File so
   * at least we will avoid to add in the wrong node some relations
   * that should not exist.
   *)
  if Hashtbl.mem env.dupes node
  then env
  else { env with cur = { env.cur with node = node } }

let add_node_and_has_edge ?props a b =
  Common.profile_code "Graph_php.add_node_and_has_edge" (fun () ->
    add_node_and_has_edge2 ?props a b)

(*****************************************************************************)
(* Add edge helpers *)
(*****************************************************************************)

let lookup_fail env tokopt dst =
  let info = Ast.tok_of_ident ("", tokopt) in
  let file, line = Parse_info.file_of_info info, Parse_info.line_of_info info in
  let fprinter =
    if env.phase = Inheritance
    then env.pr2_and_log
    else
      if file =~ ".*third-party" || file =~ ".*third_party"
      then (fun _s -> ())
      else 
        (match snd dst with
        (* todo: fix those too | E.ClassConstant *)
        | E.Function | E.Class _ | E.Constant -> env.pr2_and_log
        | _ -> env.log
        )
  in
  env.stats.G.lookup_fail +> Common.push2 (info, dst);
  fprinter (spf "PB: lookup fail on %s (at %s:%d)" (G.string_of_node dst) 
              (env.path file) line)

(* I think G.parent is extremely slow in ocamlgraph so need memoize *)
let _hmemo_class_exits = Hashtbl.create 101
let class_exists2 env (R aclass) _tokopt =
  assert (env.phase = Uses);
  let node = (aclass, E.Class E.RegularClass) in
  let node' = (normalize aclass, E.Class E.RegularClass) in
  Common.memoized _hmemo_class_exits aclass (fun () ->
    (G.has_node node env.g && 
       (* opti: this is super slow: G.parent node env.g <> G.not_found *)
       Hashtbl.mem env.not_found node
    ) ||
      Hashtbl.mem env.case_insensitive node'
  )
let class_exists a b c =
  Common.profile_code "Graph_php.class_exits" (fun () -> class_exists2 a b c)

(*****************************************************************************)
(* Add edge *)
(*****************************************************************************)

let rec add_use_edge2 env (name, kind) =
  let src = env.cur.node in
  let (R str, tokopt) = strtok_of_name env name kind in
  let dst = (str, kind) in
  match () with
  (* maybe nested function, in which case we dont have the def *)
  | _ when not (G.has_node src env.g) ->
      env.pr2_and_log 
        (spf "LOOKUP SRC FAIL %s --> %s, src doesn't exist (nested func?)"
           (G.string_of_node src) (G.string_of_node dst));

  (* ok everything is fine, let's add an edge *)
  | _ when G.has_node dst env.g ->
      G.add_edge (src, dst) G.Use env.g

  | _ when Hashtbl.mem env.case_insensitive (normalize str, kind) ->
      let (final_str, _) = 
        Hashtbl.find env.case_insensitive (normalize str, kind) in
      (*env.pr2_and_log (spf "CASE SENSITIVITY: %s instead of %s at %s"
                         str final_str 
                         (Parse_info.string_of_info (Ast.tok_of_ident name)));
      *)
      add_use_edge2 env ([final_str, tokopt], kind)

  | _ ->
    (match kind with
      (* if dst is a Class, then try Interface?
      | E.Class E.RegularClass ->
          add_use_edge env (name, E.Class E.Interface)
      *)
      (* not used for now
      | E.Class E.RegularClass ->
          add_use_edge env (name, E.Type)
      (* do not add such a node *)
      | E.Type -> ()
      *)
    | _  ->
      (match kind with
        (* todo: regular fields, fix those at some point! *)
        | E.Field when not (xhp_field str) -> ()
        | E.Field when xhp_data_field str -> ()
        | E.Method _ when magic_methods str -> 
           (* less: env.stat.G.unresolved_method_calls *)
           ()
        | _ ->
          lookup_fail env tokopt dst;
          if !add_fake_node_when_undefined_entity then begin
            G.add_node dst env.g;
            let parent_target = G.not_found in
            env.g +> G.add_edge (parent_target, dst) G.Has;
            Hashtbl.replace env.not_found dst true;
            env.g +> G.add_edge (src, dst) G.Use;
          end
        )
    )

let add_use_edge_bis a b =
  Common.profile_code "Graph_php.add_use_edge" (fun() -> add_use_edge2 a b)

let add_use_edge ?(phase=Uses) env n =
  match phase with
  | Defs -> raise Impossible
  | Inheritance -> env.phase_inheritance +> Common.push2 (env.cur, n)
  | Uses -> env.phase_use +> Common.push2 (env.cur, n)

(* why not call add_use_edge() and benefit from the error reporting
 * there? because instanceOf check are less important so
 * we special case them?
 *)
let add_use_edge_instanceof env (name, kind) =
  let env = { env with phase = Uses } in
  env.phase_use_other +> Common.push2 (fun () ->
    let (R x) = str_of_name env name kind in
    let node = x, kind in
    if not (G.has_node node env.g) 
    then env.log (spf "PB: instanceof unknown class: %s"(G.string_of_node node))
  )

(* todo: add unit test for that *)
let add_use_edge_maybe_class env entity tokopt =
  let env = { env with phase = Uses } in
  env.phase_use_other +> Common.push2 (fun () ->
    (* less: do case insensitive? handle conflicts? *)
    if G.has_node (entity, E.Class E.RegularClass) env.g
    then
      (match env.cur.readable with
      (* phabricator/fb specific *)
      | s when s =~ ".*__phutil_library_map__.php" -> ()
      | s when s =~ ".*autoload_map.php" -> ()
      | _ ->
        (*env.log (spf "DYNCALL_STR:%s (at %s)" s env.readable);*)
        add_use_edge_bis env ([entity, tokopt], E.Class E.RegularClass)
      )
  )

(*****************************************************************************)
(* Lookup *)
(*****************************************************************************)

(* less: handle privacy? 
 * assume namespace have been resolved so aclass is fully resolved
 *)
let lookup_inheritance2 g (R aclass, amethod_or_field_or_constant) tokopt =
  let rec depth current =
    if not (G.has_node current g)
    (* todo? raise Impossible? the class should exist no? *)
    then None
    else
      let children = G.children current g in
      let full_name = (fst current ^ "." ^ amethod_or_field_or_constant) in
      let res =
        children +> Common.find_some_opt (fun (s2, kind) ->
          if full_name =$= s2 || 
             (* todo? pass a is_static extra param to lookup? 
              * also should intercept __get for fields?
              *)
             s2 =$= (fst current ^ ".__call") || 
             s2 =$= (fst current ^ ".__callStatic")
          then Some ((R s2, tokopt), kind)
          else None
        )
      in
      match res with
      | Some x -> Some x
      | None ->
        (* Always inheritance? There is no other use of a Class?
         * Some new X() are not linked to the __construct
         * but to the class, but then it is in the 'pred', not the 'succ'
         * so we are fine.
         * less: assert all parents are indeed E.Class.
         *)
        let parents_inheritance = G.succ current G.Use g in
        breath parents_inheritance
  and breath xs = xs +> Common.find_some_opt depth
  in
  depth (aclass, E.Class E.RegularClass)

let lookup_inheritance g a b =
  Common.profile_code "Graph_php.lookup" (fun () -> lookup_inheritance2 g a b)


let add_use_edge_lookup2 xhp env (name, ident) kind =

  let aclass = str_of_name env name (E.Class E.RegularClass) in
  let afld = Ast.str_of_ident ident ^ (if xhp then "=" else "") in
  let tokopt = snd ident in

  (match lookup_inheritance env.g (aclass, afld) tokopt with
  (* less: assert kind = kind2? 
   * actually because we convert some Obj_get into Class_get,
   * this could also be a kind = Field even when asked for a StaticVar
   *)
  | Some ((R str, tokopt), kind2) -> 
      let tok = Ast.tok_of_ident ident in
      (match kind2 with
      | E.Method _ -> 
        env.stats.G.method_calls +> Common.push2 (tok, true)
      | E.Field -> 
        env.stats.G.field_access +> Common.push2 (tok, true)
      | E.ClassConstant -> ()
      | _ -> raise Impossible
      );
      add_use_edge_bis env ([str, tokopt], kind2)
  | None ->
    (match afld with
    (* todo? create a fake default constructor node? *)
    | "__construct" -> ()
    | _ -> 
     (* If someone uses an undefined class constant of an undefined class,
      * we want really to report only the use of undefined class, so don't
      * forget to guard some calls to add_use_edge() with this function.
      *)
      if not (class_exists env aclass tokopt)
      (* should have been reported when we visit the Class_get *)
      then 
        (* todo: we should do check at 'use' time, lazy check or hook checks
         * to be added in env.
         *)
        if aclass <> (R "NOPARENT_INTRAIT")
        (* this will create a fake node for this class *)
        then add_use_edge_bis env (name, E.Class E.RegularClass)
        else ()
      else 
        let (R str) = aclass in
        let node = ([str ^ "." ^ afld, tokopt], kind) in
        add_use_edge_bis env node
    )
  );
  (* Some classes may appear as dead because a 'new X()' is
   * transformed into a 'Call (... "__construct")' and such a method
   * may not exist, or may have been "lookup"ed to the parent.
   * So for "__construct" we also create an edge to the class
   * directly.
   * todo? but then a Use of a class can then be either a 'new' or
   * an inheritance? People using G.pred or G.succ must take care to
   * filter classes.
   *)
  if afld =$= "__construct" 
  then add_use_edge_bis env (name, E.Class E.RegularClass)

let add_use_edge_lookup ?(xhp=false) env a b =
  env.phase_use_lookup +> Common.push2 (env.cur, (xhp, a, b))

(* todo: add unit test for this 
 * todo: this is buggy, you can't use lookup_inheritance in the
 * inheritance phase! have a phase_inheristance2!
*)
let adjust_edge_protected env fld parent =
  raise Todo
(*
  let env = { env with phase = Inheritance } in
  env.phase_inheritance +> Common.push2 (fun () ->
    (* todo? handle trait and interface here? can redefine field? *)
    (match parent with
    | None -> ()
    | Some c ->
       (* todo: factorize with add_use_edge_inheritance ? *)
      let aclass, afld = 
        (str_of_class_name env c, Ast.str_of_ident fld.cv_name) in
      let fake_tok = () in
      (match lookup_inheritance env.g (aclass, afld) fake_tok with
      | None -> ()
            (* redefining an existing field *)
      | Some ((s, _fake_tok), _kind) ->
        (*env.log (spf "REDEFINED protected %s in class %s" s env.self);*)
        let parent = G.parent env.cur.node env.g in
        (* was using env.self for parent node, but in files with
         * duplicated classes, the parent may be the File so
         * let's use G.parent, safer.
         *)
        env.g +> G.remove_edge (parent, env.cur.node) G.Has;
        env.g +> G.add_edge (G.dupe, env.cur.node) G.Has;
      )
    )
  )
*)

(*****************************************************************************)
(* Defs/Uses *)
(*****************************************************************************)
let rec extract_defs_uses env ast readable =
  let env = { env with cur = { env.cur with
    node = (readable, E.File); 
    readable 
  }} in
  begin
    let dir = Common2.dirname env.cur.readable in
    G.create_intermediate_directories_if_not_present env.g dir;
    env.g +> G.add_node (env.cur.readable, E.File);
    env.g +> G.add_edge ((dir, E.Dir), (env.cur.readable, E.File))  G.Has;
  end;
  stmt_toplevel_list env ast

and stmt_toplevel_list env xs =
  match xs with
  | [] -> ()
  | x::xs ->
    (match x with
    | NamespaceUse (qu, sopt) ->
        let new_name =
          match sopt, List.rev qu with
          | Some (str, _tok), _ -> str
          | None, [] -> raise Impossible
          | None, (str,_tok)::rest -> str
        in
        let import_rules = (new_name, qu)::env.cur.import_rules in
        stmt_toplevel_list { env with cur = { env.cur with import_rules }} xs
    | _ ->
        stmt_toplevel env x;
        stmt_toplevel_list env xs
    )

(* ---------------------------------------------------------------------- *)
(* Stmt/toplevel *)
(* ---------------------------------------------------------------------- *)
and stmt_toplevel env x =
  stmt_bis env x
and stmt env x =
  stmt_bis { env with cur = {env.cur with at_toplevel = false }} x
and stmt_bis env x =
  match x with
  (* boilerplate *)
  | FuncDef def -> func_def env def
  | ClassDef def -> class_def env def
  | ConstantDef def -> constant_def env def
  | TypeDef def -> type_def env def
  | NamespaceDef (qu, xs) -> 
    stmt_toplevel_list 
      {env with cur = { env.cur with qualifier = prune_special_root qu; }} xs
  (* handled in stmt_toplevel_list *)
  | NamespaceUse _ -> ()

  (* old style constant definition, before PHP 5.4 *)
  | Expr(Call(Id[("define", _)], [String((name)); v])) ->
     let env = add_node_and_has_edge env (name, E.Constant) in
     expr env v

  | Expr e -> expr env e
  | Block xs -> stmtl env xs
  | If (e, st1, st2) ->
      expr env e;
      stmtl env [st1;st2]
  | Switch (e, xs) ->
      expr env e;
      casel env xs
  | While (e, xs) | Do (xs, e) ->
      expr env e;
      stmtl env xs
  | For (es1, es2, es3, xs) ->
      exprl env (es1 ++ es2 ++ es3);
      stmtl env xs
  | Foreach (e1, e2, xs) ->
      exprl env [e1;e2];
      stmtl env xs;
  | Return eopt  | Break eopt | Continue eopt ->
      Common2.opt (expr env) eopt
  | Throw e -> expr env e
  | Try (xs, c1, cs) ->
      stmtl env xs;
      catches env (c1::cs)

  | StaticVars xs ->
      xs +> List.iter (fun (name, eopt) -> Common2.opt (expr env) eopt)
  (* could add entity for that? *)
  | Global xs -> exprl env xs

(* todo: add deps to type hint? *)
and catch env (_hint_type, _name, xs) =
  stmtl env xs

and case env = function
  | Case (e, xs) ->
      expr env e;
      stmtl env xs
  | Default xs ->
      stmtl env xs

and stmtl env xs = List.iter (stmt env) xs
and casel env xs = List.iter (case env) xs
and catches env xs = List.iter (catch env) xs

(* ---------------------------------------------------------------------- *)
(* Defs *)
(* ---------------------------------------------------------------------- *)
and func_def env def =
  let env =
    match def.f_kind with
    | AnonLambda -> env
    | Function -> add_node_and_has_edge env (def.f_name, E.Function)
    | Method -> raise Impossible
  in
  def.f_params +> List.iter (fun p ->
    (* less: add deps to type hint? *)
    Common2.opt (expr env) p.p_default;
  );
  stmtl env def.f_body

and class_def env def =
  let kind =
    match def.c_kind with
    | ClassRegular | ClassFinal | ClassAbstract -> E.RegularClass
    | Interface -> (*E.Interface*) E.RegularClass
    | Trait -> (*E.Trait*) E.RegularClass
  in
  let env = add_node_and_has_edge env (def.c_name, E.Class kind) in
  def.c_extends +> Common.do_option (fun c2 ->
    (* todo: also mark as use the generic arguments *)
    add_use_edge ~phase:Inheritance env (name_of_class_name c2, E.Class E.RegularClass);
  );
  def.c_implements +> List.iter (fun c2 ->
    add_use_edge ~phase:Inheritance env (name_of_class_name c2, E.Class E.RegularClass (*E.Interface*));
  );
  def.c_uses +> List.iter (fun c2 ->
    add_use_edge ~phase:Inheritance env (name_of_class_name c2, E.Class E.RegularClass (*E.Trait*));
  );
  def.c_xhp_attr_inherit +> List.iter (fun c2 ->
    add_use_edge ~phase:Inheritance env (name_of_class_name c2, E.Class E.RegularClass);
  );

  let self = Ast.str_of_ident def.c_name in
  let in_trait = match def.c_kind with Trait -> true | _ -> false in
  (* opti? do not capture def, otherwise can lead to memory leak *)
  let extend = def.c_extends in
  let parent () =
    match extend with
    | None -> if not in_trait then R "NOPARENT" else R "NOPARENT_INTRAIT"
    | Some c2 -> str_of_class_name env c2
  in
  let env = { env with cur = { env.cur with self; parent; }} in

  def.c_constants +> List.iter (fun def ->
    let env = add_node_and_has_edge env (def.cst_name, E.ClassConstant) in
    expr env def.cst_body;
  );
  (* See URL: https://github.com/facebook/xhp/wiki "Defining Attributes" *)
  def.c_xhp_fields +> List.iter (fun (def, req) ->
    let node = (addpostfix def.cv_name, E.Field) in
    let props = if req then [E.Required] else [] in
    let env = add_node_and_has_edge ~props env node in
    Common2.opt (expr env) def.cv_value;
  );
  def.c_variables +> List.iter (fun fld ->
    let props = [E.Privacy (privacy_of_modifiers fld.cv_modifiers)] in
    let env = add_node_and_has_edge ~props env (fld.cv_name, E.Field)in
    (* PHP allows to refine a field, for instance on can do
     * 'protected $foo = 42;' in a class B extending A which contains
     * such a field (also this field could have been declared
     * as Public there.
     *)
(* TODO this is buggy, and maybe slow
    if privacy_of_modifiers fld.cv_modifiers =*= E.Protected
    then adjust_edge_protected env fld def.c_extends;
*)
    Common2.opt (expr env) fld.cv_value
  );
  def.c_methods +> List.iter (fun def ->
    (* less: be more precise at some point *)
    let kind = E.RegularMethod in
    let props = [E.Privacy (privacy_of_modifiers def.m_modifiers)] in
    let env = add_node_and_has_edge ~props env (def.f_name, E.Method kind) in
    stmtl env def.f_body
  )

and constant_def env def =
  let env = add_node_and_has_edge env (def.cst_name, E.Constant) in
  expr env def.cst_body

and type_def env def =
 let env = add_node_and_has_edge env (def.t_name, E.Type) in
 type_def_kind env def.t_kind

and type_def_kind env = function
  | Alias t | Newtype t -> hint_type env t

(* ---------------------------------------------------------------------- *)
(* Types *)
(* ---------------------------------------------------------------------- *)
and hint_type env t = 
  match t with 
  | Hint name -> 
    (* todo: handle basic types, could also add them in php_stdlib/ *)
    add_use_edge env (name, E.Class E.RegularClass)
  | HintArray -> ()
  | HintQuestion t -> hint_type env t
  | HintTuple xs -> List.iter (hint_type env) xs
  | HintCallback (tparams, tret_opt) ->
      List.iter (hint_type env) tparams;
      Common.opt (hint_type env) tret_opt
  | HintShape xs ->
    xs +> List.iter (fun (_ket, t) ->
      hint_type env t
    )

(* ---------------------------------------------------------------------- *)
(* Expr *)
(* ---------------------------------------------------------------------- *)
and expr env x =
  match x with
  | Int _ | Double _  -> ()

  (* A String in PHP can actually hide a class (or a function) *)
  | String (s, tokopt) when look_like_class s ->
    (* less: could also be a class constant or field or method *)
    let entity = Common.matched1 s in
    add_use_edge_maybe_class env entity tokopt

  (* todo? also look for functions? but has more FPs with regular
   * fields. Need to avoid this FP either by not calling
   * the String visitor when inside an array where all fields are
   * short or some field do not correspond to an existing function
   *)
  | String _ -> ()

  (* Note that you should go here only when it's a constant. You should
   * catch the use of Id in other contexts before. For instance you
   * should match on Id in Call, Class_get, Obj_get so that this code
   * is executed really as a last resort, which usually means when
   * there is the use of a constant.
   *)
  | Id name -> add_use_edge env (name, E.Constant)
  (* a parameter or local variable *)
  | Var ident -> ()

  (* -------------------------------------------------- *)
  | Call (e, es) ->
    (match e with
    (* simple function call *)
    | Id name ->
        add_use_edge env (name, E.Function);
        exprl env es

    (* static method call *)
    | Class_get (Id[ ("__special__self", tokopt)], e2) ->
        expr env (Call (Class_get (Id[ (env.cur.self, tokopt)], e2), es))
    | Class_get (Id[ ("__special__parent", tokopt)], e2) ->
        let name = name_of_parent env tokopt in
        expr env (Call (Class_get (Id name, e2), es))
    (* incorrect actually ... but good enough for now for codegraph *)
    | Class_get (Id[ ("__special__static", tokopt)], e2) ->
        expr env (Call (Class_get (Id[ (env.cur.self, tokopt)], e2), es))

    | Class_get (Id name1, Id [name2]) ->
         (* can be static or regular method as transform $this->foo()
          * in env.self::foo() below
          *)
         add_use_edge_lookup env (name1, name2) (E.Method E.RegularMethod);
         exprl env es

    (* object call *)
    | Obj_get (e1, Id name2) ->
        (match e1 with
        (* handle easy case *)
        | This ((x, tokopt)) ->
          expr env (Call (Class_get (Id[ (env.cur.self, tokopt)], Id name2), es))
        (* TODO: need class analysis ... *)
        | _ ->
          let tok = Ast.tok_of_name name2 in
          env.stats.G.method_calls +> Common.push2 (tok, false);
          expr env e1;
          exprl env es
        )
    | _ ->
      let tok = Meta_ast_php_simple.toks_of_any (Expr2 e) +> List.hd in
      env.stats.G.unresolved_calls +> Common.push2 tok;
      expr env e;
      exprl env es
    (* less: increment dynamic_fails stats also when use func_call_args() *)
    )

  (* -------------------------------------------------- *)
  (* This should be executed only for access to class constants or static
   * class variable; calls should have been catched in the Call pattern above.
   *)
  | Class_get (e1, e2) ->
      (match e1, e2 with
      | Id[ ("__special__self", tokopt)], _ ->
          expr env (Class_get (Id[(env.cur.self, tokopt)], e2))
      | Id[ ("__special__parent", tokopt)], _ ->
          let name = name_of_parent env tokopt in
          expr env (Class_get (Id name, e2))
      (* incorrect actually ... but good enough for now for codegraph *)
      | Id[ ("__special__static", tokopt)], _ ->
          expr env (Class_get (Id[ (env.cur.self, tokopt)], e2))

      | Id name1, Id [name2] ->
          add_use_edge_lookup env (name1, name2) E.ClassConstant
      | Id name1, Var name2 ->
          add_use_edge_lookup env (name1, name2) E.Field

     | Id name1, e2  ->
         let tok = Ast.tok_of_name name1 in
         env.stats.G.unresolved_class_access +> Common.push2 tok;
         add_use_edge env (name1, E.Class E.RegularClass);
         expr env e2;
     | e1, Id name2  ->
         let tok = Ast.tok_of_name name2 in
         env.stats.G.unresolved_class_access +> Common.push2 tok;
         expr env e1;
     | _ ->
         let tok = Meta_ast_php_simple.toks_of_any (Expr2 e1) +> List.hd in
         env.stats.G.unresolved_class_access +> Common.push2 tok;
         exprl env [e1; e2]
      )

  (* same, should be executed only for field access *)
  | Obj_get (e1, e2) ->
      (match e1, e2 with
      (* handle easy case *)
      | This (_, tokopt), Id [name2] ->
          let (s2, tok2) = name2 in
          expr env (Class_get (Id[ (env.cur.self, tokopt)], Var ("$" ^ s2, tok2)))
      | _, Id name2  ->
          let tok = Ast.tok_of_name name2 in
          env.stats.G.field_access +> Common.push2 (tok, false);
          expr env e1;
      | _ ->
          let tok = Meta_ast_php_simple.toks_of_any (Expr2 e1) +> List.hd in
          env.stats.G.unresolved_class_access +> Common.push2 tok;
          exprl env [e1; e2]
      )

  | New (e, es) ->
      let tok = Meta_ast_php_simple.toks_of_any (Expr2 e) +> List.hd in
      expr env (Call (Class_get(e, Id[ ("__construct", Some tok)]), es))

  (* -------------------------------------------------- *)
  | InstanceOf (e1, e2) ->
      expr env e1;
      (match e2 with
      (* less: add deps? *)
      | Id name -> add_use_edge_instanceof env (name, E.Class E.RegularClass)
      | _ ->
          let tok = Meta_ast_php_simple.toks_of_any (Expr2 e1) +> List.hd in
          env.stats.G.unresolved_class_access +> Common.push2 tok;
          expr env e2
      )

  (* boilerplate *)
  | Arrow(e1, e2) -> exprl env [e1;e2]
  | List xs -> exprl env xs
  | Assign (_, e1, e2) -> exprl env [e1;e2]

  | This _ -> ()
  | Array_get (e, eopt) ->
      expr env e;
      Common2.opt (expr env) eopt
  | Infix (_, e) | Postfix (_, e) | Unop (_, e) -> expr env e
  | Binop (_, e1, e2) -> exprl env [e1; e2]
  | Guil xs -> exprl env xs
  | Ref e -> expr env e
  | ConsArray (xs) -> array_valuel env xs
  | Collection (name, xs) ->
      add_use_edge env (name, E.Class E.RegularClass);
      array_valuel env xs
  | Xhp x -> xml env x
  | CondExpr (e1, e2, e3) -> exprl env [e1; e2; e3]
  (* less: again, add deps for type? *)
  | Cast (_, e) -> expr env e
  | Lambda def -> func_def env def
  

and array_value env x = expr env x
and vector_value env e = expr env e
and map_value env (e1, e2) = exprl env [e1; e2]

and xml env x =
  add_use_edge env ([x.xml_tag], E.Class E.RegularClass);
  x.xml_attrs +> List.iter (fun (ident, xhp_attr) ->
    add_use_edge_lookup ~xhp:true env ([x.xml_tag], ident) E.Field;
    expr env xhp_attr
  );
  x.xml_body +> List.iter (xhp env)

and xhp env = function
  | XhpText s -> ()
  | XhpExpr e -> expr env e
  | XhpXml x -> xml env x

and exprl         env xs = List.iter (expr env) xs
and array_valuel  env xs = List.iter (array_value env) xs
and vector_valuel env xs = List.iter (vector_value env) xs
and map_valuel    env xs = List.iter (map_value env) xs

(*****************************************************************************)
(* Main entry point *)
(*****************************************************************************)

let build 
    ?(verbose=true)
    ?(logfile=(Filename.concat (Sys.getcwd()) "pfff.log"))
    ?(readable_file_format=false)
    ?(only_defs=false)
    dir_or_files skip_list 
 =
  let root, files =
    Common.profile_code "Graph_php.step0" (fun () ->
    match dir_or_files with
    | Left dir ->
      let root = Common.realpath dir in
      let all_files = Lib_parsing_php.find_php_files_of_dir_or_files [root] in

      (* step0: filter noisy modules/files *)
      let files = 
        Skip_code.filter_files skip_list root all_files in
      (* step0: reorder files *)
      let files = 
        Skip_code.reorder_files_skip_errors_last skip_list root files in
      root, files
    (* useful when build codegraph from test code *)
    | Right files ->
      "/", files
    )
  in
      
  let g = G.create () in
  G.create_initial_hierarchy g;

  let chan = open_out logfile in
  let env = {
    g;
    phase = Defs;
    phase_inheritance = ref [];
    phase_use = ref [];
    phase_use_lookup = ref [];
    phase_use_other = ref [];
    cur = {
      node = ("filled_later", E.File);
      readable = "filled_later";
      qualifier = [];
      import_rules = [];
      self = "NOSELF"; 
      parent = (fun () -> R "NOPARENT");
      at_toplevel = true;
    };
    dupes = Hashtbl.create 101;
    (* set after the defs phase *)
    case_insensitive = Hashtbl.create 101;
    not_found = Hashtbl.create 101;
    stats = Graph_code.empty_statistics ();
    log = (fun s ->
        output_string chan (s ^ "\n");
        flush chan;
    );
    pr2_and_log = (fun s ->
      if verbose then pr2 s;
      output_string chan (s ^ "\n");
      flush chan;
    );
    is_skip_error_file = Skip_code.build_filter_errors_file skip_list;
    (* This function is useful for testing. In particular, the paths in
       tests/php/codegraoph/pfff_test.exp use readable path, so that
       make test can work from any machine.
    *)
    path = (fun file -> 
      if readable_file_format
      then Common.filename_without_leading_path root file
      else file);
  }
  in

  (* step1: creating the nodes and 'Has' edges, the defs *)
  env.pr2_and_log "\nstep1: extract defs";
  Common.profile_code "Graph_php.step1" (fun () ->
  files +> Common_extra.progress ~show:verbose (fun k ->
    List.iter (fun file ->
      k();
      let readable = Common.filename_without_leading_path root file in
      let ast = parse env file in
      (* will modify env.dupes instead of raise Graph_code.NodeAlreadyPresent *)
      extract_defs_uses { env with phase = Defs} ast readable;
   ));
  );
  Common.profile_code "Graph_php.step dupes" (fun () ->
  Common2.hkeys env.dupes
  +> List.filter (fun (_, kind) ->
    match kind with
    | E.ClassConstant | E.Field | E.Method _ -> false
    | _ -> true
  )
  +> List.iter (fun node ->
    let files = Hashtbl.find_all env.dupes node in
    let (ex_file, _) = List.hd files in
    let orig_file = 
      try G.file_of_node node g 
      with Not_found ->
        failwith (spf "PB with %s, no file found, dupes = %s"
                    (G.string_of_node node) (Common.dump files))
    in

    let dupes = orig_file::List.map fst files in
    let cnt = List.length dupes in

    let (in_skip_errors, other) =
      List.partition env.is_skip_error_file dupes in

    (match List.length in_skip_errors, List.length other with
    (* dupe in regular codebase, bad *)
    | _, n when n >= 2 ->
      env.pr2_and_log  (spf "DUPE: %s (%d)" (G.string_of_node node) cnt);
      g +> G.remove_edge (G.parent node g, node) G.Has;
      g +> G.add_edge (G.dupe, node) G.Has;
      env.log (spf " orig = %s" (orig_file));
      env.log (spf " dupe = %s" (ex_file));
    (* duplicating a regular function, bad, but ok, should have renamed it in
     * our analysis, see env.dupe_renaming
     *)
    | n, 1 when n > 0 ->
      env.log (spf "DUPE BAD STYLE: %s (%d)" (G.string_of_node node) cnt);
      env.log (spf " orig = %s" (orig_file));
      env.log (spf " dupe = %s" (ex_file));
    (* probably local functions to a script duplicated in independent files,
     * most should have also been renamed, see env.dupe_renaming *)
    | n, 0 -> ()
    | _ -> raise Impossible
    )
  );
  );
  if not only_defs then begin
    g +> G.iter_nodes (fun (str, kind) ->
      Hashtbl.replace env.case_insensitive (normalize str, kind) (str, kind)
    );

    (* step2: creating the 'Use' edges for inheritance *)
    env.pr2_and_log "\nstep2: extract inheritance";
    Common.profile_code "Graph_php.step2" (fun () ->
      !(env.phase_inheritance) +> List.rev +> List.iter (fun (cur, n) ->
        let env = { env with phase = Inheritance; cur } in
        add_use_edge_bis env n
      );
      env.phase_inheritance := [];
    );
    (* step3: creating the 'Use' edges, the uses *)
    env.pr2_and_log "\nstep3: extract uses";
    Common.profile_code "Graph_php.step3" (fun () ->

      !(env.phase_use) +> List.rev +> List.iter (fun (cur, n) ->
        let env = { env with phase = Uses; cur } in
        add_use_edge_bis env n
      );
      env.phase_use := [];

      !(env.phase_use_lookup) +> List.rev +> List.iter (fun (cur, (xhp, a, b))->
        let env = { env with phase = Uses; cur } in
        add_use_edge_lookup2 xhp env a b
      );
      env.phase_use_lookup := [];

      let xs = !(env.phase_use_other) in
      (env.phase_use_other) := [];
      xs +> List.rev +> List.iter (fun f -> f());
    );
  end;
  close_out chan;
  g, env.stats
