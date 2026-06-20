//
//  HUDMainApplicationDelegate.mm
//  TrollSpeed
//

#import <objc/runtime.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"
#import "HUDRootViewController.h"
#import "HUDOverlayScene.h"
#import "ImGuiHUDView.h"

#import "SBSAccessibilityWindowHostingController.h"
#import "UIWindow+Private.h"

@implementation HUDMainApplicationDelegate {
    HUDRootViewController *_rootViewController;
    HUDOverlayScene *_overlayScene;
    SBSAccessibilityWindowHostingController *_windowHostingController;
}

- (instancetype)init
{
    if (self = [super init]) {
        log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate init]");
    }
    return self;
}

- (void)registerWindowWithSpringBoard:(UIWindow *)window
{
    _windowHostingController = [[objc_getClass("SBSAccessibilityWindowHostingController") alloc] init];
    unsigned int contextId = [window _contextId];
    double windowLevel = [window windowLevel];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:_windowHostingController];
    [invocation setSelector:NSSelectorFromString(@"registerWindowWithContextID:atLevel:")];
    [invocation setArgument:&contextId atIndex:2];
    [invocation setArgument:&windowLevel atIndex:3];
    [invocation invoke];
#pragma clang diagnostic pop
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions
{
    (void)application;
    (void)launchOptions;

    _rootViewController = [[HUDRootViewController alloc] init];

    // 1. FrontBoard Scene：在桌面创建系统层 overlay（apibug 同款思路）
    _overlayScene = [[HUDOverlayScene alloc] init];
    BOOL sceneReady = [_overlayScene activate];

    // 2. UIWindow：用于触摸注入与 SpringBoard 窗口托管
    self.window = [[HUDMainWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.opaque = NO;
    self.window.backgroundColor = UIColor.clearColor;
    [self.window setRootViewController:_rootViewController];
    [self.window setWindowLevel:10000010.0];
    [self.window setHidden:NO];
    [self.window makeKeyAndVisible];

    [self registerWindowWithSpringBoard:self.window];

    // 3. 将 ImGui 视图挂到 FrontBoard 系统层（优先），否则回退到 UIWindow
    (void)_rootViewController.view;
    ImGuiHUDView *imguiView = _rootViewController.imguiView;
    if (sceneReady && _overlayScene.hostView && imguiView) {
        [imguiView removeFromSuperview];
        imguiView.frame = _overlayScene.hostView.bounds;
        imguiView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_overlayScene.hostView addSubview:imguiView];
        log_debug(OS_LOG_DEFAULT, "ImGui mounted on FrontBoard overlay scene");
    } else {
        log_debug(OS_LOG_DEFAULT, "FrontBoard scene unavailable, ImGui stays on UIWindow");
    }

    return YES;
}

@end
