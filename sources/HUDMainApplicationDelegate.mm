//
//  HUDMainApplicationDelegate.mm
//  TrollSpeed
//

#import <objc/runtime.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"
#import "HUDRootViewController.h"

#import "SBSAccessibilityWindowHostingController.h"
#import "UIWindow+Private.h"

@implementation HUDMainApplicationDelegate {
    HUDRootViewController *_rootViewController;
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

    // ImGui 必须留在 SBS 托管的 UIWindow 内，才能持久显示在桌面。
    // FrontBoard Scene 的 presentationView 在部分系统版本上不可见，且会导致 displayLink 暂停。
    self.window = [[HUDMainWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.opaque = NO;
    self.window.backgroundColor = UIColor.clearColor;
    [self.window setRootViewController:_rootViewController];
    [self.window setWindowLevel:10000010.0];
    [self.window setHidden:NO];
    [self.window makeKeyAndVisible];

    [self registerWindowWithSpringBoard:self.window];

    return YES;
}

@end
