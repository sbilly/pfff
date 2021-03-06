package com.android.server.wm;
class WindowToken {
  int sendingToBottom;
  int waitingToHide;
  int waitingToShow;
  int hasVisible;
  int hidden;
  int paused;
  int windows;
  int appWindowToken;
  int stringName;
  int explicit;
  int windowType;
  int token;
  int service;
}
class WindowStateAnimator {
  class SurfaceTrace {
    int mName;
    int mShown;
    int mWindowCrop;
    int mSize;
    int mPosition;
    int mLayer;
    int mSurfaceTraceAlpha;
    int sSurfaces;
    int SURFACE_TAG;
  }
  int mAttrType;
  int mAttrFlags;
  int mLastHidden;
  int mDrawState;
  int HAS_DRAWN;
  int READY_TO_SHOW;
  int COMMIT_DRAW_PENDING;
  int DRAW_PENDING;
  int NO_SURFACE;
  int mEnterAnimationPending;
  int mSurfaceAlpha;
  int mSurfaceLayer;
  int mSurfaceH;
  int mSurfaceW;
  int mSurfaceY;
  int mSurfaceX;
  int mSurfaceShown;
  int mHaveMatrix;
  int mLastDtDy;
  int mLastDsDy;
  int mLastDtDx;
  int mLastDsDx;
  int mDtDy;
  int mDsDy;
  int mDtDx;
  int mDsDx;
  int mAnimDh;
  int mAnimDw;
  int mLastAlpha;
  int mAlpha;
  int mShownAlpha;
  int mSurfaceDestroyDeferred;
  int mSurfaceResized;
  int mPendingDestroySurface;
  int mSurface;
  int mLastLayer;
  int mAnimLayer;
  int mWasAnimating;
  int mTransformation;
  int mHasLocalTransformation;
  int mHasTransformation;
  int mAnimationIsEntrance;
  int mAnimation;
  int mLocalAnimating;
  int mAnimating;
  int mContext;
  int mPolicy;
  int mSession;
  int mAnimator;
  int mAttachedWindow;
  int mWin;
  int mService;
  int TAG;
  int DEBUG_SURFACE_TRACE;
  int DEBUG_ORIENTATION;
  int localLOGV;
  int SHOW_SURFACE_ALLOC;
  int SHOW_LIGHT_TRANSACTIONS;
  int SHOW_TRANSACTIONS;
  int DEBUG_STARTING_WINDOW;
  int DEBUG_LAYERS;
  int DEBUG_ANIM;
  int DEBUG_VISIBILITY;
}
class WindowState {
  class DeathRecipient {
  }
  int mHasSurface;
  int mWinAnimator;
  int mWasPaused;
  int mLastTitle;
  int mStringNameCache;
  int mInputChannel;
  int mInputWindowHandle;
  int mRebuilding;
  int mRemoved;
  int mOrientationChanging;
  int mRemoveOnExit;
  int mDestroying;
  int mExiting;
  int mLayoutNeeded;
  int mRelayoutCalled;
  int mYOffset;
  int mXOffset;
  int mWallpaperYStep;
  int mWallpaperXStep;
  int mWallpaperY;
  int mWallpaperX;
  int mContentChanged;
  int mVisibleFrame;
  int mParentFrame;
  int mContentFrame;
  int mDisplayFrame;
  int mContainingFrame;
  int mCompatFrame;
  int mLastFrame;
  int mFrame;
  int mTmpMatrix;
  int mLastVScale;
  int mLastHScale;
  int mVScale;
  int mHScale;
  int mInvGlobalScale;
  int mGlobalScale;
  int mLastSystemDecorRect;
  int mSystemDecorRect;
  int mTouchableInsets;
  int mGivenTouchableRegion;
  int mGivenVisibleInsets;
  int mGivenContentInsets;
  int mGivenInsetsPending;
  int mContentInsetsChanged;
  int mLastContentInsets;
  int mContentInsets;
  int mVisibleInsetsChanged;
  int mLastVisibleInsets;
  int mVisibleInsets;
  int mShownFrame;
  int mConfiguration;
  int mLayoutSeq;
  int mTurnOnScreen;
  int mObscured;
  int mHaveFrame;
  int mLayer;
  int mLastRequestedHeight;
  int mLastRequestedWidth;
  int mRequestedHeight;
  int mRequestedWidth;
  int mWallpaperVisible;
  int mAttachedHidden;
  int mAppFreezing;
  int mPolicyVisibilityAfterAnim;
  int mPolicyVisibility;
  int mSystemUiVisibility;
  int mViewVisibility;
  int mEnforceSizeCompat;
  int mSeq;
  int mIsFloatingLayer;
  int mIsWallpaper;
  int mIsImWindow;
  int mLayoutAttached;
  int mSubLayer;
  int mBaseLayer;
  int mChildWindows;
  int mAttachedWindow;
  int mDeathRecipient;
  int mAttrs;
  int mTargetAppToken;
  int mAppToken;
  int mRootToken;
  int mToken;
  int mClient;
  int mSession;
  int mContext;
  int mPolicy;
  int mService;
  int SHOW_SURFACE_ALLOC;
  int SHOW_LIGHT_TRANSACTIONS;
  int SHOW_TRANSACTIONS;
  int DEBUG_VISIBILITY;
  int TAG;
}
class WindowManagerService {
  class OnHardKeyboardStatusChangeListener {
  }
  int mInLayout;
  class H {
    int mLastReportedHold;
    int CLEAR_PENDING_ACTIONS;
    int SET_DIM_PARAMETERS;
    int SET_WALLPAPER_OFFSET;
    int SET_TRANSPARENT_REGION;
    int ANIMATOR_WHAT_OFFSET;
    int DO_ANIMATION_CALLBACK;
    int SHOW_STRICT_MODE_VIOLATION;
    int BULK_UPDATE_PARAMETERS;
    int WAITING_FOR_DRAWN_TIMEOUT;
    int BOOT_TIMEOUT;
    int REPORT_HARD_KEYBOARD_STATUS_CHANGE;
    int DRAG_END_TIMEOUT;
    int DRAG_START_TIMEOUT;
    int REPORT_WINDOWS_CHANGE;
    int SEND_NEW_CONFIGURATION;
    int APP_FREEZE_TIMEOUT;
    int ENABLE_SCREEN;
    int FORCE_GC;
    int PERSIST_ANIMATION_SCALE;
    int APP_TRANSITION_TIMEOUT;
    int HOLD_SCREEN_CHANGED;
    int WINDOW_FREEZE_TIMEOUT;
    int REPORT_APPLICATION_TOKEN_DRAWN;
    int REPORT_APPLICATION_TOKEN_WINDOWS;
    int FINISHED_STARTING;
    int REMOVE_STARTING;
    int ADD_STARTING;
    int DO_TRAVERSAL;
    int REPORT_LOSING_FOCUS;
    int REPORT_FOCUS_CHANGE;
  }
  int mEventDispatchingEnabled;
  int mInputMonitor;
  int ADJUST_WALLPAPER_VISIBILITY_CHANGED;
  int ADJUST_WALLPAPER_LAYERS_CHANGED;
  class PolicyThread {
    int mRunning;
    int mPM;
    int mContext;
    int mService;
    int mPolicy;
  }
  class WMThread {
    int mOnlyCore;
    int mAllowBootMessages;
    int mHaveInputMethods;
    int mPM;
    int mContext;
    int mService;
  }
  int mOnlyCore;
  int mCompatibleScreenScale;
  int mTempConfiguration;
  class WindowChangeListener {
  }
  int mWindowsChanged;
  int mWindowChangeListeners;
  int mViewServer;
  int mInTouchMode;
  class DragInputEventReceiver {
  }
  int mAnimator;
  int mAnimationScheduled;
  int mAnimationRunnable;
  class AnimationRunnable {
  }
  int mLayoutRepeatCount;
  int mTransactionSequence;
  int mInnerFields;
  class LayoutFields {
    int mUpdateRotation;
    int mButtonBrightness;
    int mScreenBrightness;
    int mSyswin;
    int mDimming;
    int mObscured;
    int mHoldScreen;
    int mAdjResult;
    int mOrientationChangeComplete;
    int mWallpaperMayChange;
    int mWallpaperForceHidingChanged;
    int SET_TURN_ON_SCREEN;
    int CLEAR_ORIENTATION_CHANGE_COMPLETE;
    int SET_FORCE_HIDING_CHANGED;
    int SET_WALLPAPER_MAY_CHANGE;
    int SET_UPDATE_ROTATION;
  }
  int mDragState;
  int mTurnOnScreen;
  int mHoldingScreenWakeLock;
  int mHoldingScreenOn;
  int mInputManager;
  int mAnimatorDurationScale;
  int mTransitionAnimationScale;
  int mWindowAnimationScale;
  int mPowerManager;
  int mFocusedApp;
  int WALLPAPER_TIMEOUT_RECOVERY;
  int WALLPAPER_TIMEOUT;
  int mLastWallpaperTimeoutTime;
  int mWaitingOnWallpaper;
  int mLastWallpaperYStep;
  int mLastWallpaperXStep;
  int mLastWallpaperY;
  int mLastWallpaperX;
  int mWallpaperAnimLayerAdjustment;
  int mUpperWallpaperTarget;
  int mLowerWallpaperTarget;
  int mWallpaperTarget;
  int mWallpaperTokens;
  int mHardKeyboardStatusChangeListener;
  int mHardKeyboardEnabled;
  int mHardKeyboardAvailable;
  int mInputMethodDialogs;
  int mInputMethodWindow;
  int mInputMethodAnimLayerAdjustment;
  int mInputMethodTargetWaitingAnim;
  int mInputMethodTarget;
  int mLastFocus;
  int mCurrentFocus;
  int mChoreographer;
  int mH;
  int mCompatDisplayMetrics;
  int mTmpDisplayMetrics;
  int mRealDisplayMetrics;
  int mDisplayMetrics;
  int mIsTouchDevice;
  int mDisplay;
  int mClosingApps;
  int mOpeningApps;
  int mSkipAppTransitionAnimation;
  int mStartingIconInTransition;
  int mAppTransitionTimeout;
  int mAppTransitionRunning;
  int mAppTransitionReady;
  int mNextAppTransitionStartHeight;
  int mNextAppTransitionStartWidth;
  int mNextAppTransitionStartY;
  int mNextAppTransitionStartX;
  int mNextAppTransitionExit;
  int mNextAppTransitionEnter;
  int mNextAppTransitionCallback;
  int mNextAppTransitionDelayed;
  int mNextAppTransitionThumbnail;
  int mNextAppTransitionPackage;
  int mNextAppTransitionType;
  int mNextAppTransition;
  int mScreenFrozenLock;
  int mCurConfiguration;
  int mFocusMayChange;
  int mLastStatusBarVisibility;
  int mLayoutSeq;
  int mLastWindowForcedOrientation;
  int mAppsFreezingScreen;
  int mWindowsFreezingScreen;
  int mWaitingForConfig;
  int mDisplayFrozen;
  int mTraversalScheduled;
  int mLayoutNeeded;
  int mPendingLayoutChanges;
  int mSystemDecorLayer;
  int mSystemDecorRect;
  int mDeferredRotationPauseCount;
  int mRotationWatchers;
  int mAltOrientation;
  int mForcedAppOrientation;
  int mRotation;
  int mLargestDisplayHeight;
  int mLargestDisplayWidth;
  int mSmallestDisplayHeight;
  int mSmallestDisplayWidth;
  int mAppDisplayHeight;
  int mAppDisplayWidth;
  int mCurDisplayHeight;
  int mCurDisplayWidth;
  int mBaseDisplayHeight;
  int mBaseDisplayWidth;
  int mInitialDisplayHeight;
  int mInitialDisplayWidth;
  int mDisplaySizeLock;
  int mLastANRState;
  int mShowingBootMessages;
  int mForceDisplayEnabled;
  int mSystemBooted;
  int mDisplayEnabled;
  int mSafeMode;
  int mTmpFloats;
  int mBlackFrame;
  int mStrictModeFlash;
  int mWatermark;
  int mFxSession;
  int mInputMethodManager;
  int mRebuildTmp;
  int mRelayoutWhileAnimating;
  int mWaitingForDrawn;
  int mForceRemoves;
  int mLosingFocus;
  int mDestroySurface;
  int mPendingRemoveTmp;
  int mPendingRemove;
  int mResizingWindows;
  int mFakeWindows;
  int mWindows;
  int mFinishedStarting;
  int mExitingAppTokens;
  int mAnimatingAppTokens;
  int mAppTokens;
  int mExitingTokens;
  int mTokenMap;
  int mWindowMap;
  int mSessions;
  int mBatteryStats;
  int mActivityManager;
  int mPolicy;
  int mLimitedAlphaCompositing;
  int mAllowBootMessages;
  int mHaveInputMethods;
  int mContext;
  int mBroadcastReceiver;
  int mKeyguardTokenWatcher;
  int THUMBNAIL_ANIMATION_DECELERATE_FACTOR;
  int mAllowDisableKeyguard;
  int ALLOW_DISABLE_UNKNOWN;
  int ALLOW_DISABLE_NO;
  int ALLOW_DISABLE_YES;
  int mHeadless;
  int mKeyguardDisabled;
  int SYSTEM_HEADLESS;
  int SYSTEM_DEBUGGABLE;
  int SYSTEM_SECURE;
  int UPDATE_FOCUS_WILL_PLACE_SURFACES;
  int UPDATE_FOCUS_PLACING_SURFACES;
  int UPDATE_FOCUS_WILL_ASSIGN_LAYERS;
  int UPDATE_FOCUS_NORMAL;
  int DEFAULT_INPUT_DISPATCHING_TIMEOUT_NANOS;
  int INPUT_DEVICES_READY_FOR_SAFE_MODE_DETECTION_TIMEOUT_MILLIS;
  int CUSTOM_SCREEN_ROTATION;
  int DEFAULT_FADE_IN_OUT_DURATION;
  int DEFAULT_DIM_DURATION;
  int MAX_ANIMATION_DURATION;
  int MASK_LAYER;
  int FREEZE_LAYER;
  int LAYER_OFFSET_THUMBNAIL;
  int LAYER_OFFSET_BLUR;
  int LAYER_OFFSET_DIM;
  int WINDOW_LAYER_MULTIPLIER;
  int TYPE_LAYER_OFFSET;
  int TYPE_LAYER_MULTIPLIER;
  int localLOGV;
  int PROFILE_ORIENTATION;
  int LAYOUT_REPEAT_THRESHOLD;
  int HIDE_STACK_CRAWLS;
  int SHOW_LIGHT_TRANSACTIONS;
  int SHOW_TRANSACTIONS;
  int SHOW_SURFACE_ALLOC;
  int DEBUG_WINDOW_TRACE;
  int DEBUG_SURFACE_TRACE;
  int DEBUG_LAYOUT_REPEATS;
  int DEBUG_BOOT;
  int DEBUG_SCREENSHOT;
  int DEBUG_SCREEN_ON;
  int DEBUG_DRAG;
  int DEBUG_WALLPAPER;
  int DEBUG_REORDER;
  int DEBUG_STARTING_WINDOW;
  int DEBUG_APP_TRANSITIONS;
  int DEBUG_CONFIGURATION;
  int DEBUG_APP_ORIENTATION;
  int DEBUG_ORIENTATION;
  int DEBUG_TOKEN_MOVEMENT;
  int DEBUG_WINDOW_MOVEMENT;
  int DEBUG_VISIBILITY;
  int DEBUG_INPUT_METHOD;
  int DEBUG_INPUT;
  int DEBUG_LAYERS;
  int DEBUG_RESIZE;
  int DEBUG_LAYOUT;
  int DEBUG_ANIM;
  int DEBUG_FOCUS;
  int DEBUG_ADD_REMOVE;
  int DEBUG;
  int TAG;
}
class WindowAnimator {
  class SetAnimationParams {
    int mAnimDh;
    int mAnimDw;
    int mAnimation;
    int mWinAnimator;
  }
  int mCurrentFocus;
  int mPendingActions;
  int WALLPAPER_ACTION_PENDING;
  int mDimParams;
  int mDimAnimator;
  int mBulkUpdateParams;
  int mWindowAnimationBackgroundSurface;
  int mDetachedWallpaper;
  int mWindowDetachedWallpaper;
  int mScreenRotationAnimation;
  int mAnimTransactionSequence;
  int mCurrentTime;
  int mInnerDh;
  int mInnerDw;
  int mDh;
  int mDw;
  int mPendingLayoutChanges;
  int mAdjResult;
  int mWindowAnimationBackgroundColor;
  int mWindowAnimationBackground;
  int mForceHiding;
  int mAnimating;
  int mWinAnimators;
  int mPolicy;
  int mContext;
  int mService;
  int TAG;
}
class Watermark {
  int mDrawNeeded;
  int mLastDH;
  int mLastDW;
  int mSurface;
  int mDeltaY;
  int mDeltaX;
  int mTextDescent;
  int mTextAscent;
  int mTextHeight;
  int mTextWidth;
  int mTextPaint;
  int mText;
  int mTokens;
}
class ViewServer {
  class ViewServerWorker {
    int mNeedFocusedWindowUpdate;
    int mNeedWindowListUpdate;
    int mClient;
  }
  int mThreadPool;
  int mPort;
  int mWindowManager;
  int mThread;
  int mServer;
  int COMMAND_WINDOW_MANAGER_GET_FOCUS;
  int COMMAND_WINDOW_MANAGER_AUTOLIST;
  int COMMAND_WINDOW_MANAGER_LIST;
  int COMMAND_SERVER_VERSION;
  int COMMAND_PROTOCOL_VERSION;
  int VALUE_SERVER_VERSION;
  int VALUE_PROTOCOL_VERSION;
  int LOG_TAG;
  int VIEW_SERVER_MAX_CONNECTIONS;
  int VIEW_SERVER_DEFAULT_PORT;
}
class StrictModeFlash {
  int mThickness;
  int mDrawNeeded;
  int mLastDH;
  int mLastDW;
  int mSurface;
  int TAG;
}
class StartingData {
  int windowFlags;
  int icon;
  int labelRes;
  int nonLocalizedLabel;
  int compatInfo;
  int theme;
  int pkg;
}
class Session {
  int mClientDead;
  int mNumWindow;
  int mSurfaceSession;
  int mStringName;
  int mPid;
  int mUid;
  int mInputContext;
  int mClient;
  int mService;
}
class ScreenRotationAnimation {
  int mHalfwayPoint;
  int mMoreStartFrame;
  int mMoreStartExit;
  int mMoreStartEnter;
  int mMoreFinishFrame;
  int mMoreFinishExit;
  int mMoreFinishEnter;
  int mMoreRotateFrame;
  int mMoreRotateExit;
  int mMoreRotateEnter;
  int mTmpFloats;
  int mTmpMatrix;
  int mExitFrameFinalMatrix;
  int mSnapshotFinalMatrix;
  int mSnapshotInitialMatrix;
  int mFrameInitialMatrix;
  int mFinishAnimStartTime;
  int mFinishAnimReady;
  int mAnimRunning;
  int mStarted;
  int mFrameTransformation;
  int mEnterTransformation;
  int mExitTransformation;
  int mLastRotateFrameTransformation;
  int mLastRotateFrameAnimation;
  int mLastRotateEnterTransformation;
  int mLastRotateEnterAnimation;
  int mLastRotateExitTransformation;
  int mLastRotateExitAnimation;
  int mRotateFrameTransformation;
  int mRotateFrameAnimation;
  int mRotateEnterTransformation;
  int mRotateEnterAnimation;
  int mRotateExitTransformation;
  int mRotateExitAnimation;
  int mFinishFrameTransformation;
  int mFinishFrameAnimation;
  int mFinishEnterTransformation;
  int mFinishEnterAnimation;
  int mFinishExitTransformation;
  int mFinishExitAnimation;
  int mStartFrameTransformation;
  int mStartFrameAnimation;
  int mStartEnterTransformation;
  int mStartEnterAnimation;
  int mStartExitTransformation;
  int mStartExitAnimation;
  int mCurRotation;
  int mOriginalHeight;
  int mOriginalWidth;
  int mOriginalRotation;
  int mHeight;
  int mWidth;
  int mEnteringBlackFrame;
  int mExitingBlackFrame;
  int mCustomBlackFrame;
  int mSurface;
  int mContext;
  int FREEZE_LAYER;
  int USE_CUSTOM_BLACK_FRAME;
  int TWO_PHASE_ANIMATION;
  int DEBUG_TRANSFORMS;
  int DEBUG_STATE;
  int TAG;
}
class InputMonitor {
  int mInputDevicesReady;
  int mInputDevicesReadyMonitor;
  int mInputWindowHandleCount;
  int mInputWindowHandles;
  int mUpdateInputWindowsNeeded;
  int mInputDispatchEnabled;
  int mInputDispatchFrozen;
  int mInputFocus;
  int mService;
}
class FakeWindowImpl {
  int mTouchFullscreen;
  int mWindowLayer;
  int mInputEventReceiver;
  int mWindowHandle;
  int mApplicationHandle;
  int mClientChannel;
  int mServerChannel;
  int mService;
}
class DragState {
  int mTmpRegion;
  int mDragInProgress;
  int mNotifiedWindows;
  int mTargetWindow;
  int mDragWindowHandle;
  int mDragApplicationHandle;
  int mInputEventReceiver;
  int mClientChannel;
  int mServerChannel;
  int mThumbOffsetY;
  int mThumbOffsetX;
  int mCurrentY;
  int mCurrentX;
  int mDragResult;
  int mDataDescription;
  int mData;
  int mLocalWin;
  int mFlags;
  int mSurface;
  int mToken;
  int mService;
}
class DimSurface {
  int mLastDimHeight;
  int mLastDimWidth;
  int mLayer;
  int mDimColor;
  int mDimShown;
  int mDimSurface;
}
class DimAnimator {
  class Parameters {
    int mDimTarget;
    int mDimHeight;
    int mDimWidth;
    int mDimWinAnimator;
  }
  int mLastDimHeight;
  int mLastDimWidth;
  int mLastDimAnimTime;
  int mDimDeltaPerMs;
  int mDimTargetAlpha;
  int mDimCurrentAlpha;
  int mDimShown;
  int mDimSurface;
}
class BlackFrame {
  int mBlackSurfaces;
  int mTmpFloats;
  int mTmpMatrix;
  int mInnerRect;
  int mOuterRect;
  class BlackSurface {
    int surface;
    int layer;
    int top;
    int left;
  }
}
class AppWindowToken {
  int mInputApplicationHandle;
  int firstWindowDrawn;
  int startingMoved;
  int startingDisplayed;
  int startingView;
  int startingWindow;
  int startingData;
  int removed;
  int reportedDrawn;
  int reportedVisible;
  int clientHidden;
  int hiddenRequested;
  int willBeHidden;
  int allDrawn;
  int inPendingTransaction;
  int numDrawnWindows;
  int numInterestingWindows;
  int lastTransactionSequence;
  int inputDispatchingTimeoutNanos;
  int requestedOrientation;
  int appFullscreen;
  int groupId;
  int mAnimator;
  int mAppAnimator;
  int allAppWindows;
  int appToken;
}
class AppWindowAnimator {
  class DummyAnimation {
  }
  int sDummyAnimation;
  int thumbnailTransformation;
  int thumbnailAnimation;
  int thumbnailLayer;
  int thumbnailY;
  int thumbnailX;
  int thumbnailTransactionSeq;
  int thumbnail;
  int allDrawn;
  int animLayerAdjustment;
  int freezingScreen;
  int transformation;
  int hasTransformation;
  int animInitialized;
  int animation;
  int animating;
  int mAnimator;
  int mService;
  int mAppToken;
  int TAG;
}
