//
//  HUDRootViewController.mm
//  TrollSpeed
//
//  ImGui HUD 根视图控制器。
//

#import <notify.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#import "HUDRootViewController.h"
#import "ImGuiHUDView.h"
#import "TrollSpeed-Swift.h"

#import "FBSOrientationUpdate.h"
#import "FBSOrientationObserver.h"
#import "UIApplication+Private.h"
#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"
#import "SpringBoardServices.h"

#define NOTIFY_UI_LOCKSTATE    "com.apple.springboard.lockstate"
#define NOTIFY_LS_APP_CHANGED  "com.apple.LaunchServices.ApplicationsChanged"

static void LaunchServicesApplicationStateChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    (void)center;
    (void)observer;
    (void)name;
    (void)object;
    (void)userInfo;

    BOOL isAppInstalled = NO;
    for (LSApplicationProxy *app in [[objc_getClass("LSApplicationWorkspace") defaultWorkspace] allApplications]) {
        if ([app.applicationIdentifier isEqualToString:@"ch.xxtou.hudapp"]) {
            isAppInstalled = YES;
            break;
        }
    }

    if (!isAppInstalled) {
        [[UIApplication sharedApplication] terminateWithSuccess];
    }
}

static void SpringBoardLockStatusChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    (void)center;
    (void)name;
    (void)object;
    (void)userInfo;

    HUDRootViewController *rootViewController = (__bridge HUDRootViewController *)observer;
    NSString *lockState = (__bridge NSString *)name;
    if (![lockState isEqualToString:@NOTIFY_UI_LOCKSTATE]) {
        return;
    }

    mach_port_t sbsPort = SBSSpringBoardServerPort();
    if (sbsPort == MACH_PORT_NULL) {
        return;
    }

    BOOL isLocked = NO;
    BOOL isPasscodeSet = NO;
    SBGetScreenLockStatus(sbsPort, &isLocked, &isPasscodeSet);

    if (!isLocked) {
        [rootViewController.view setHidden:NO];
        [rootViewController resetLoopTimer];
    } else {
        [rootViewController stopLoopTimer];
        [rootViewController.view setHidden:YES];
    }
}

#pragma mark - HUDRootViewController

@interface HUDRootViewController (Troll)
- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration;
@end

@implementation HUDRootViewController {
    NSMutableDictionary *_userDefaults;
    ImGuiHUDView *_imguiView;
    FBSOrientationObserver *_orientationObserver;
    UIInterfaceOrientation _orientation;
    NSMutableArray<NSLayoutConstraint *> *_constraints;
}

- (void)registerNotifications
{
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_HUD, &token, dispatch_get_main_queue(), ^(int token) {
        (void)token;
        [self reloadUserDefaults];
    });

    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        LaunchServicesApplicationStateChanged,
        CFSTR(NOTIFY_LS_APP_CHANGED),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        SpringBoardLockStatusChanged,
        CFSTR(NOTIFY_UI_LOCKSTATE),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
}

- (void)loadUserDefaults:(BOOL)forceReload
{
    if (forceReload || !_userDefaults) {
        _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:TS_JBROOT_PATH(USER_DEFAULTS_PATH)] mutableCopy] ?: [NSMutableDictionary dictionary];
    }
}

- (void)reloadUserDefaults
{
    [self loadUserDefaults:YES];

    NSNumber *displayMode = [_userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode];
    BOOL showDemo = displayMode ? [displayMode boolValue] : NO;
    [ImGuiHUDView setShowDemoWindow:showDemo];
    [ImGuiHUDView setMenuVisible:YES];
}

- (ImGuiHUDView *)imguiView
{
    return _imguiView;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _constraints = [NSMutableArray array];
        [self registerNotifications];
        _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
        __weak HUDRootViewController *weakSelf = self;
        [_orientationObserver setHandler:^(FBSOrientationUpdate *orientationUpdate) {
            HUDRootViewController *strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf updateOrientation:(UIInterfaceOrientation)orientationUpdate.orientation animateWithDuration:orientationUpdate.duration];
            });
        }];
    }
    return self;
}

- (void)dealloc
{
    [_orientationObserver invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;
    self.view.opaque = NO;

    _imguiView = [[ImGuiHUDView alloc] initWithFrame:self.view.bounds];
    _imguiView.translatesAutoresizingMaskIntoConstraints = NO;
    _imguiView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:_imguiView];

    UITapGestureRecognizer *showMenuGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showImGuiMenu:)];
    showMenuGesture.numberOfTapsRequired = 2;
    showMenuGesture.numberOfTouchesRequired = 3;
    [self.view addGestureRecognizer:showMenuGesture];

    UITapGestureRecognizer *hideMenuGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideImGuiMenu:)];
    hideMenuGesture.numberOfTapsRequired = 2;
    hideMenuGesture.numberOfTouchesRequired = 2;
    [self.view addGestureRecognizer:hideMenuGesture];

    [self reloadUserDefaults];
}

+ (BOOL)passthroughMode
{
    return [[[NSDictionary dictionaryWithContentsOfFile:TS_JBROOT_PATH(USER_DEFAULTS_PATH)] objectForKey:HUDUserDefaultsKeyPassthroughMode] boolValue];
}

- (BOOL)usesRotation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)showImGuiMenu:(UITapGestureRecognizer *)sender
{
    (void)sender;
    [ImGuiHUDView setMenuVisible:YES];
}

- (void)hideImGuiMenu:(UITapGestureRecognizer *)sender
{
    (void)sender;
    [ImGuiHUDView setMenuVisible:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (_imguiView) {
        [_imguiView resumeRendering];
        [_imguiView setNeedsLayout];
        [_imguiView layoutIfNeeded];
    }

    [@"" writeToFile:TS_JBROOT_PATH(HUD_READY_PATH) atomically:YES encoding:NSUTF8StringEncoding error:nil];
    notify_post(NOTIFY_LAUNCHED_HUD);
}

- (void)resetLoopTimer
{
}

- (void)stopLoopTimer
{
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self updateViewConstraints];
}

- (void)updateViewConstraints
{
    [NSLayoutConstraint deactivateConstraints:_constraints];
    [_constraints removeAllObjects];

    if (_imguiView) {
        [_constraints addObjectsFromArray:@[
            [_imguiView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [_imguiView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            [_imguiView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [_imguiView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        ]];
    }

    [NSLayoutConstraint activateConstraints:_constraints];
    [super updateViewConstraints];
}

@end

@implementation HUDRootViewController (Troll)

static inline CGFloat orientationAngle(UIInterfaceOrientation orientation)
{
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            return M_PI;
        case UIInterfaceOrientationLandscapeLeft:
            return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight:
            return M_PI_2;
        default:
            return 0;
    }
}

static inline CGRect orientationBounds(UIInterfaceOrientation orientation, CGRect bounds)
{
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            return CGRectMake(0, 0, bounds.size.height, bounds.size.width);
        default:
            return bounds;
    }
}

- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration
{
    if (_imguiView) {
        _imguiView.alpha = 1.0;
    }

    if (![self usesRotation]) {
        return;
    }

    if (orientation == _orientation) {
        return;
    }

    _orientation = orientation;

    CGRect bounds = orientationBounds(orientation, [UIScreen mainScreen].bounds);
    [self.view setNeedsUpdateConstraints];
    [self.view setHidden:YES];
    [self.view setBounds:bounds];

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:duration animations:^{
        [weakSelf.view setTransform:CGAffineTransformMakeRotation(orientationAngle(orientation))];
    } completion:^(BOOL finished) {
        (void)finished;
        [weakSelf.view setHidden:NO];
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end
