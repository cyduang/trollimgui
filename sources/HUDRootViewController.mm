//
//  HUDRootViewController.mm
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

#import <notify.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <objc/runtime.h>
#import <mach/vm_param.h>
#import <Foundation/Foundation.h>

#import "HUDPresetPosition.h"
#import "HUDRootViewController.h"
#import "HUDBackdropLabel.h"
#import "ImGuiHUDView.h"
#import "TrollSpeed-Swift.h"

#ifdef __cplusplus
extern "C" {
#endif
CFIndex CARenderServerGetDirtyFrameCount(void *);
#ifdef __cplusplus
}
#endif

#pragma mark -

#import "FBSOrientationUpdate.h"
#import "FBSOrientationObserver.h"
#import "UIApplication+Private.h"
#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"
#import "SpringBoardServices.h"

#define NOTIFY_UI_LOCKSTATE    "com.apple.springboard.lockstate"
#define NOTIFY_LS_APP_CHANGED  "com.apple.LaunchServices.ApplicationsChanged"

static BOOL needsBaselineReset = YES;
static BOOL needsFPSBaselineReset = YES;

static void LaunchServicesApplicationStateChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    /* Application installed or uninstalled */

    BOOL isAppInstalled = NO;

    for (LSApplicationProxy *app in [[objc_getClass("LSApplicationWorkspace") defaultWorkspace] allApplications])
    {
        if ([app.applicationIdentifier isEqualToString:@"ch.xxtou.hudapp"])
        {
            isAppInstalled = YES;
            break;
        }
    }

    if (!isAppInstalled)
    {
        UIApplication *app = [UIApplication sharedApplication];
        [app terminateWithSuccess];
    }
}

static void SpringBoardLockStatusChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    HUDRootViewController *rootViewController = (__bridge HUDRootViewController *)observer;
    NSString *lockState = (__bridge NSString *)name;
    if ([lockState isEqualToString:@NOTIFY_UI_LOCKSTATE])
    {
        mach_port_t sbsPort = SBSSpringBoardServerPort();

        if (sbsPort == MACH_PORT_NULL)
            return;

        BOOL isLocked;
        BOOL isPasscodeSet;
        SBGetScreenLockStatus(sbsPort, &isLocked, &isPasscodeSet);

        if (!isLocked)
        {
            needsBaselineReset = YES;
            needsFPSBaselineReset = YES;
            [rootViewController.view setHidden:NO];
            [rootViewController resetLoopTimer];
        }
        else
        {
            [rootViewController stopLoopTimer];
            [rootViewController.view setHidden:YES];
        }
    }
}

#pragma mark - NetworkSpeed13

#define KILOBITS 1000
#define MEGABITS 1000000
#define GIGABITS 1000000000
#define KILOBYTES (1 << 10)
#define MEGABYTES (1 << 20)
#define GIGABYTES (1 << 30)
#define UPDATE_INTERVAL 1.0
#define SHOW_ALWAYS 1
#define INLINE_SEPARATOR "\t"
#define IDLE_INTERVAL 3.0

static const double HUD_MIN_FONT_SIZE = 9.0;
static const double HUD_MAX_FONT_SIZE = 10.0;
static const double HUD_MIN_CORNER_RADIUS = 4.5;
static const double HUD_MAX_CORNER_RADIUS = 5.0;
static double HUD_FONT_SIZE = 8.0;
static UIFontWeight HUD_FONT_WEIGHT = UIFontWeightRegular;
static CGFloat HUD_INACTIVE_OPACITY = 0.667;
static uint8_t HUD_DATA_UNIT = 0;
static uint8_t HUD_SHOW_UPLOAD_SPEED = 1;
static uint8_t HUD_SHOW_DOWNLOAD_SPEED = 1;
static uint8_t HUD_SHOW_DOWNLOAD_SPEED_FIRST = 1;
static uint8_t HUD_SHOW_SECOND_SPEED_IN_NEW_LINE = 0;
static const char *HUD_UPLOAD_PREFIX = "▲";
static const char *HUD_DOWNLOAD_PREFIX = "▼";
static uint8_t HUD_DISPLAY_MODE = 0;  // 0=Speed, 1=FPS

typedef struct {
    uint64_t inputBytes;
    uint64_t outputBytes;
} UpDownBytes;

static NSString *formattedSpeed(uint64_t bytes, BOOL isFocused)
{
    if (isFocused)
    {
        if (0 == HUD_DATA_UNIT)
        {
            if (bytes < KILOBYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"0 KB", @"formattedSpeed");
                });
                return _string;
            }
            else if (bytes < MEGABYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.0f KB", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / KILOBYTES];
            }
            else if (bytes < GIGABYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f MB", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / MEGABYTES];
            }
            else {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f GB", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / GIGABYTES];
            }
        }
        else
        {
            if (bytes < KILOBITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"0 Kb", @"formattedSpeed");
                });
                return _string;
            }
            else if (bytes < MEGABITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.0f Kb", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / KILOBITS];
            }
            else if (bytes < GIGABITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f Mb", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / MEGABITS];
            }
            else {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f Gb", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / GIGABITS];
            }
        }
    }
    else {
        if (0 == HUD_DATA_UNIT)
        {
            if (bytes < KILOBYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"0 KB/s", @"formattedSpeed");
                });
                return _string;
            }
            else if (bytes < MEGABYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.0f KB/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / KILOBYTES];
            }
            else if (bytes < GIGABYTES) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f MB/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / MEGABYTES];
            }
            else {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f GB/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / GIGABYTES];
            }
        }
        else
        {
            if (bytes < KILOBITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"0 Kb/s", @"formattedSpeed");
                });
                return _string;
            }
            else if (bytes < MEGABITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.0f Kb/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / KILOBITS];
            }
            else if (bytes < GIGABITS) {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f Mb/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / MEGABITS];
            }
            else {
                static NSString *_string = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    _string = NSLocalizedString(@"%.2f Gb/s", @"formattedSpeed");
                });
                return [NSString stringWithFormat:_string, (double)bytes / GIGABITS];
            }
        }
    }
}

static UpDownBytes getUpDownBytes()
{
    struct ifaddrs *ifa_list = 0, *ifa;
    UpDownBytes upDownBytes;
    upDownBytes.inputBytes = 0;
    upDownBytes.outputBytes = 0;

    if (getifaddrs(&ifa_list) == -1) return upDownBytes;

    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next)
    {
        /* Skip invalid interfaces */
        if (ifa->ifa_name == NULL || ifa->ifa_addr == NULL || ifa->ifa_data == NULL)
            continue;

        /* Skip interfaces that are not link level interfaces */
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;

        /* Skip interfaces that are not up or running */
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;

        /* Skip interfaces that are not ethernet or cellular */
        if (strncmp(ifa->ifa_name, "en", 2) && strncmp(ifa->ifa_name, "pdp_ip", 6))
            continue;

        struct if_data *if_data = (struct if_data *)ifa->ifa_data;

        upDownBytes.inputBytes += if_data->ifi_ibytes;
        upDownBytes.outputBytes += if_data->ifi_obytes;
    }

    freeifaddrs(ifa_list);
    return upDownBytes;
}

static BOOL shouldUpdateSpeedLabel;
static uint64_t prevOutputBytes = 0, prevInputBytes = 0;
static CFIndex prevDirtyFrameCount = 0;
static NSAttributedString *attributedUploadPrefix = nil;
static NSAttributedString *attributedDownloadPrefix = nil;
static NSAttributedString *attributedInlineSeparator = nil;
static NSAttributedString *attributedLineSeparator = nil;

static NSAttributedString *formattedAttributedString(BOOL isFocused)
{
    @autoreleasepool
    {
        if (!attributedUploadPrefix)
            attributedUploadPrefix = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:HUD_UPLOAD_PREFIX] stringByAppendingString:@" "] attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];
        if (!attributedDownloadPrefix)
            attributedDownloadPrefix = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:HUD_DOWNLOAD_PREFIX] stringByAppendingString:@" "] attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];
        if (!attributedInlineSeparator)
            attributedInlineSeparator = [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:INLINE_SEPARATOR] attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];
        if (!attributedLineSeparator)
            attributedLineSeparator = [[NSAttributedString alloc] initWithString:@"\n" attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:HUD_FONT_SIZE] }];

        NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] init];

        UpDownBytes upDownBytes = getUpDownBytes();

        uint64_t upDiff;
        uint64_t downDiff;

        if (needsBaselineReset && !isFocused)
        {
            prevOutputBytes = upDownBytes.outputBytes;
            prevInputBytes = upDownBytes.inputBytes;
            needsBaselineReset = NO;
            shouldUpdateSpeedLabel = NO;
            return nil;
        }

        if (isFocused)
        {
            upDiff = upDownBytes.outputBytes;
            downDiff = upDownBytes.inputBytes;
        }
        else
        {
            if (upDownBytes.outputBytes > prevOutputBytes)
                upDiff = upDownBytes.outputBytes - prevOutputBytes;
            else
                upDiff = 0;

            if (upDownBytes.inputBytes > prevInputBytes)
                downDiff = upDownBytes.inputBytes - prevInputBytes;
            else
                downDiff = 0;
        }

        prevOutputBytes = upDownBytes.outputBytes;
        prevInputBytes = upDownBytes.inputBytes;

        if (!SHOW_ALWAYS && (upDiff < 2 * KILOBYTES && downDiff < 2 * KILOBYTES))
        {
            shouldUpdateSpeedLabel = NO;
            return nil;
        }
        else shouldUpdateSpeedLabel = YES;

        if (HUD_DATA_UNIT == 1)
        {
            upDiff *= BYTE_SIZE;
            downDiff *= BYTE_SIZE;
        }

        if (HUD_SHOW_DOWNLOAD_SPEED_FIRST)
        {
            if (HUD_SHOW_DOWNLOAD_SPEED)
            {
                [mutableString appendAttributedString:attributedDownloadPrefix];
                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:formattedSpeed(downDiff, isFocused) attributes:@{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT] }]];
            }

            if (HUD_SHOW_UPLOAD_SPEED)
            {
                if ([mutableString length] > 0)
                {
                    if (HUD_SHOW_SECOND_SPEED_IN_NEW_LINE) [mutableString appendAttributedString:attributedLineSeparator];
                    else [mutableString appendAttributedString:attributedInlineSeparator];
                }

                [mutableString appendAttributedString:attributedUploadPrefix];
                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:formattedSpeed(upDiff, isFocused) attributes:@{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT] }]];
            }
        }
        else
        {
            if (HUD_SHOW_UPLOAD_SPEED)
            {
                [mutableString appendAttributedString:attributedUploadPrefix];
                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:formattedSpeed(upDiff, isFocused) attributes:@{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT] }]];
            }
            if (HUD_SHOW_DOWNLOAD_SPEED)
            {
                if ([mutableString length] > 0)
                {
                    if (HUD_SHOW_SECOND_SPEED_IN_NEW_LINE) [mutableString appendAttributedString:attributedLineSeparator];
                    else [mutableString appendAttributedString:attributedInlineSeparator];
                }

                [mutableString appendAttributedString:attributedDownloadPrefix];
                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:formattedSpeed(downDiff, isFocused) attributes:@{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT] }]];
            }
        }

        return [mutableString copy];
    }
}

static NSAttributedString *formattedFPSAttributedString(BOOL isFocused)
{
    @autoreleasepool
    {
        CFIndex dirtyFrameCount = CARenderServerGetDirtyFrameCount(NULL);

        if (needsFPSBaselineReset)
        {
            prevDirtyFrameCount = dirtyFrameCount;
            needsFPSBaselineReset = NO;
            shouldUpdateSpeedLabel = YES;

            NSString *fpsString = @"0 FPS";
            return [[NSAttributedString alloc] initWithString:fpsString attributes:@{
                NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT]
            }];
        }

        CFIndex frameDiff = dirtyFrameCount - prevDirtyFrameCount;
        prevDirtyFrameCount = dirtyFrameCount;

        if (frameDiff < 0) frameDiff = 0;

        double fps = (double)frameDiff / UPDATE_INTERVAL;
        double maxFPS = (double)[UIScreen mainScreen].maximumFramesPerSecond;
        if (fps > maxFPS) fps = maxFPS;

        shouldUpdateSpeedLabel = YES;

        NSString *fpsString = [NSString stringWithFormat:@"%.0f FPS", fps];
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:fpsString attributes:@{
            NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:HUD_FONT_SIZE weight:HUD_FONT_WEIGHT]
        }];

        return attributedString;
    }
}

#pragma mark - HUDRootViewController

@interface HUDRootViewController (Troll)
- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration;
@end

static const CACornerMask kCornerMaskBottom = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
static const CACornerMask kCornerMaskAll = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;

@implementation HUDRootViewController {
    NSMutableDictionary *_userDefaults;
    NSMutableArray <NSLayoutConstraint *> *_constraints;
    UIBlurEffect *_blurEffect;
    UIVisualEffectView *_blurView;
    ScreenshotInvisibleContainer *_containerView;
    UIView *_contentView;
    HUDBackdropLabel *_speedLabel;
    UIImageView *_lockedView;
    ImGuiHUDView *_imguiView;
    NSTimer *_timer;
    UITapGestureRecognizer *_tapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
    UINotificationFeedbackGenerator *_notificationFeedbackGenerator;
    BOOL _isFocused;
    NSLayoutConstraint *_topConstraint;
    NSLayoutConstraint *_centerXConstraint;
    NSLayoutConstraint *_leadingConstraint;
    NSLayoutConstraint *_trailingConstraint;
    UIInterfaceOrientation _orientation;
    FBSOrientationObserver *_orientationObserver;
}

- (void)registerNotifications
{
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_HUD, &token, dispatch_get_main_queue(), ^(int token) {
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

    NSUserDefaults *userDefaults = GetStandardUserDefaults();
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyUsesCustomFontSize options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomFontSize options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyUsesCustomOffset options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomOffsetX options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomOffsetY options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:HUDUserDefaultsKeyUsesCustomFontSize] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomFontSize] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyUsesCustomOffset] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomOffsetX] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomOffsetY])
    {
        [self reloadUserDefaults];
    }
}

- (void)loadUserDefaults:(BOOL)forceReload
{
    if (forceReload || !_userDefaults)
        _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary];
}

- (void)saveUserDefaults
{
    BOOL wroteSucceed = [_userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES];
    if (wroteSucceed) {
        [[NSFileManager defaultManager] setAttributes:@{
            NSFileOwnerAccountID: @501,
            NSFileGroupOwnerAccountID: @501,
        } ofItemAtPath:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) error:nil];
        notify_post(NOTIFY_RELOAD_APP);
    }
}

- (void)reloadUserDefaults
{
    [self loadUserDefaults:YES];

    [self removeAllAnimations];
    [self resetGestureRecognizers];
    [self updateViewConstraints];
}

+ (BOOL)passthroughMode
{
    return [[[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] objectForKey:HUDUserDefaultsKeyPassthroughMode] boolValue];
}

- (BOOL)isLandscapeOrientation
{
    BOOL isLandscape;
    if (_orientation == UIInterfaceOrientationUnknown) {
        isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    } else {
        isLandscape = UIInterfaceOrientationIsLandscape(_orientation);
    }
    return isLandscape;
}

- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation
{
    return [self isLandscapeOrientation] ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode;
}

- (HUDPresetPosition)selectedModeForCurrentOrientation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:[self selectedModeKeyForCurrentOrientation]];
    return mode != nil ? (HUDPresetPosition)[mode integerValue] : HUDPresetPositionTopCenter;
}

- (BOOL)singleLineMode
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeySingleLineMode];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)displayMode
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyDisplayMode];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesBitrate
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesBitrate];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesArrowPrefixes
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesArrowPrefixes];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesLargeFont
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesRotation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesInvertedColor
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)keepInPlace
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)hideAtSnapshot
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot];
    return mode != nil ? [mode boolValue] : NO;
}

- (CGFloat)currentPositionY
{
    [self loadUserDefaults:NO];
    NSNumber *positionY = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentPositionY];
    return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX;
}

- (void)setCurrentPositionY:(CGFloat)positionY
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentPositionY];
    [self saveUserDefaults];
}

- (CGFloat)currentLandscapePositionY
{
    [self loadUserDefaults:NO];
    NSNumber *positionY = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX;
}

- (void)setCurrentLandscapePositionY:(CGFloat)positionY
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    [self saveUserDefaults];
}

#define PREFS_PATH "/var/mobile/Library/Preferences/ch.xxtou.hudapp.prefs.plist"

- (NSDictionary *)extraUserDefaultsDictionary {
    static BOOL isJailbroken = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      isJailbroken = [[NSFileManager defaultManager]
          fileExistsAtPath:JBROOT_PATH_NSSTRING(@"/Library/PreferenceBundles/TrollSpeedPrefs.bundle")];
    });
    if (!isJailbroken) {
        return nil;
    }
    return [NSDictionary dictionaryWithContentsOfFile:JBROOT_PATH_NSSTRING(@PREFS_PATH)];
}

- (BOOL)usesCustomFontSize {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyUsesCustomFontSize] boolValue];
    }
    return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomFontSize];
}

- (CGFloat)realCustomFontSize {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyRealCustomFontSize] doubleValue];
    }
    return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomFontSize];
}

- (BOOL)usesCustomOffset {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyUsesCustomOffset] boolValue];
    }
    return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomOffset];
}

- (CGFloat)realCustomOffsetX {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyRealCustomOffsetX] doubleValue];
    }
    return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetX];
}

- (CGFloat)realCustomOffsetY {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyRealCustomOffsetY] doubleValue];
    }
    return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetY];
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

- (void)updateSpeedLabel
{
    // 已改用 ImGui 渲染，不再更新网速标签
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // ImGui Metal 全屏叠加层，替代原网速 HUD
    _imguiView = [[ImGuiHUDView alloc] initWithFrame:self.view.bounds];
    _imguiView.translatesAutoresizingMaskIntoConstraints = NO;
    _imguiView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_imguiView];

    // 三指双击显示菜单，双指双击隐藏菜单（与 AOV 参考项目一致）
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
    notify_post(NOTIFY_LAUNCHED_HUD);
}

- (void)resetLoopTimer
{
    // ImGui 使用 MTKView 自驱动渲染，无需网速刷新定时器
}

- (void)stopLoopTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self removeAllAnimations];
    [self resetGestureRecognizers];
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
        [NSLayoutConstraint activateConstraints:_constraints];
        [super updateViewConstraints];
        return;
    }

    BOOL isLandscape;
    if (_orientation == UIInterfaceOrientationUnknown) {
        isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    } else {
        isLandscape = UIInterfaceOrientationIsLandscape(_orientation);
    }

    HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);
    BOOL isCenteredMost = (selectedMode == HUDPresetPositionTopCenterMost);
    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);

    HUD_SHOW_DOWNLOAD_SPEED_FIRST = isCentered;
    HUD_SHOW_SECOND_SPEED_IN_NEW_LINE = !isCentered;
    [_speedLabel setTextAlignment:(isCentered ? NSTextAlignmentCenter : NSTextAlignmentLeft)];
    [_lockedView setImage:[UIImage systemImageNamed:(isCentered ? @"hand.raised.slash.fill" : @"lock.fill")]];
    [_blurView.layer setMaskedCorners:((isCenteredMost && !isLandscape) ? kCornerMaskBottom : kCornerMaskAll)];

    BOOL usesCustomOffset = [self usesCustomOffset];
    CGFloat realCustomOffsetX = 0;
    CGFloat realCustomOffsetY = 0;

    if (usesCustomOffset)
    {
        realCustomOffsetX = [self realCustomOffsetX] * (-1);
        realCustomOffsetY = [self realCustomOffsetY];
    }

    UILayoutGuide *layoutGuide = self.view.safeAreaLayoutGuide;
    if (isLandscape)
    {
        CGFloat notchHeight;
        CGFloat paddingNearNotch;
        CGFloat paddingFarFromNotch;

        notchHeight = CGRectGetMinY(layoutGuide.layoutFrame);
        paddingNearNotch = (notchHeight > 30) ? notchHeight - 16 : 4;
        paddingFarFromNotch = (notchHeight > 30) ? -24 : -4;

        paddingNearNotch += realCustomOffsetX;
        paddingFarFromNotch += realCustomOffsetX;

        [_constraints addObjectsFromArray:@[
            [_contentView.leadingAnchor constraintEqualToAnchor:layoutGuide.leadingAnchor constant:(_orientation == UIInterfaceOrientationLandscapeLeft ? -paddingFarFromNotch : paddingNearNotch)],
            [_contentView.trailingAnchor constraintEqualToAnchor:layoutGuide.trailingAnchor constant:(_orientation == UIInterfaceOrientationLandscapeLeft ? -paddingNearNotch : paddingFarFromNotch)],
        ]];

        CGFloat minimumLandscapeTopConstant = 0;
        CGFloat minimumLandscapeBottomConstant = 0;

        minimumLandscapeTopConstant = (isPad ? 30 : 10);
        minimumLandscapeBottomConstant = (isPad ? -34 : -14);

        minimumLandscapeTopConstant += realCustomOffsetY;
        minimumLandscapeBottomConstant += realCustomOffsetY;

        /* Fixed Constraints */
        [_constraints addObjectsFromArray:@[
            [_contentView.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.topAnchor constant:minimumLandscapeTopConstant],
            [_contentView.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.bottomAnchor constant:minimumLandscapeBottomConstant],
        ]];

        /* Flexible Constraint */
        _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:minimumLandscapeTopConstant];
        if (!isCentered) {
            CGFloat currentPositionY = [self currentLandscapePositionY];
            if (currentPositionY < CGFLOAT_MAX) {
                _topConstraint.constant = currentPositionY;
            }
        }
        _topConstraint.priority = UILayoutPriorityDefaultLow;

        [_constraints addObject:_topConstraint];
    }
    else
    {
        [_constraints addObjectsFromArray:@[
            [_contentView.leadingAnchor constraintEqualToAnchor:layoutGuide.leadingAnchor constant:realCustomOffsetX],
            [_contentView.trailingAnchor constraintEqualToAnchor:layoutGuide.trailingAnchor constant:realCustomOffsetX],
        ]];

        if (isCenteredMost && !isPad) {
            [_constraints addObject:[_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0]];
        }
        else
        {
            CGFloat minimumTopConstraintConstant = 0;
            CGFloat minimumBottomConstraintConstant = 0;

            if (CGRectGetMinY(layoutGuide.layoutFrame) >= 51) {
                minimumTopConstraintConstant = -8;
                minimumBottomConstraintConstant = -4;
            }
            else if (CGRectGetMinY(layoutGuide.layoutFrame) > 30) {
                minimumTopConstraintConstant = -12;
                minimumBottomConstraintConstant = -4;
            } else {
                minimumTopConstraintConstant = (isPad ? 30 : 20);
                minimumBottomConstraintConstant = -20;
            }

            minimumTopConstraintConstant += realCustomOffsetY;
            minimumBottomConstraintConstant += realCustomOffsetY;

            /* Fixed Constraints */
            [_constraints addObjectsFromArray:@[
                [_contentView.topAnchor constraintGreaterThanOrEqualToAnchor:layoutGuide.topAnchor constant:minimumTopConstraintConstant],
                [_contentView.bottomAnchor constraintLessThanOrEqualToAnchor:layoutGuide.bottomAnchor constant:minimumBottomConstraintConstant],
            ]];

            /* Flexible Constraint */
            _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:layoutGuide.topAnchor constant:minimumTopConstraintConstant];
            if (!isCentered) {
                CGFloat currentPositionY = [self currentPositionY];
                if (currentPositionY < CGFLOAT_MAX) {
                    _topConstraint.constant = currentPositionY;
                }
            }
            _topConstraint.priority = UILayoutPriorityDefaultLow;

            [_constraints addObject:_topConstraint];
        }
    }

    [_constraints addObjectsFromArray:@[
        [_speedLabel.topAnchor constraintEqualToAnchor:_contentView.topAnchor],
        [_speedLabel.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor],
    ]];

    _centerXConstraint = [_speedLabel.centerXAnchor constraintEqualToAnchor:layoutGuide.centerXAnchor];
    if (isCentered) {
        [_constraints addObject:_centerXConstraint];
    }

    _leadingConstraint = [_speedLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:10];
    if (selectedMode == HUDPresetPositionTopLeft) {
        [_constraints addObject:_leadingConstraint];
    }

    _trailingConstraint = [_speedLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-10];
    if (selectedMode == HUDPresetPositionTopRight) {
        [_constraints addObject:_trailingConstraint];
    }

    [_constraints addObjectsFromArray:@[
        [_blurView.topAnchor constraintEqualToAnchor:_speedLabel.topAnchor constant:-2],
        [_blurView.leadingAnchor constraintEqualToAnchor:_speedLabel.leadingAnchor constant:-4],
        [_blurView.trailingAnchor constraintEqualToAnchor:_speedLabel.trailingAnchor constant:4],
        [_blurView.bottomAnchor constraintEqualToAnchor:_speedLabel.bottomAnchor constant:2],
    ]];

    [_constraints addObjectsFromArray:@[
        [_lockedView.topAnchor constraintGreaterThanOrEqualToAnchor:_blurView.topAnchor constant:2],
        [_lockedView.centerXAnchor constraintEqualToAnchor:_blurView.centerXAnchor],
        [_lockedView.centerYAnchor constraintEqualToAnchor:_blurView.centerYAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:_constraints];
    [super updateViewConstraints];
}

- (void)keepFocus:(UIView *)view
{
    [self onFocus:view duration:0];
}

- (void)onFocus:(UIView *)view
{
    [self onFocus:view duration:0.2];
}

- (void)onFocus:(UIView *)view duration:(NSTimeInterval)duration
{
    [self onFocus:view scaleFactor:0.1 duration:duration beginFromInitialState:YES blurWhenDone:YES];
}

- (void)onFocus:(UIView *)view scaleFactor:(CGFloat)scaleFactor duration:(NSTimeInterval)duration beginFromInitialState:(BOOL)beginFromInitialState blurWhenDone:(BOOL)blurWhenDone
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];

    _isFocused = YES;
    [self updateSpeedLabel];
    [self resetLoopTimer];

    HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);

    CGFloat topTrans = CGRectGetHeight(view.bounds) * (scaleFactor / 2);
    CGFloat leadingTrans = (isCentered ? 0 : (selectedMode == HUDPresetPositionTopLeft ? CGRectGetWidth(view.bounds) * (scaleFactor / 2) : -CGRectGetWidth(view.bounds) * (scaleFactor / 2)));

    if (beginFromInitialState)
        [view setTransform:CGAffineTransformIdentity];

    [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
        if (ABS(leadingTrans) > 1e-6 || ABS(topTrans) > 1e-6)
        {
            CGAffineTransform transform = CGAffineTransformMakeTranslation(leadingTrans, topTrans);
            view.transform = CGAffineTransformScale(transform, 1.0 + scaleFactor, 1.0 + scaleFactor);
        }

        view.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (blurWhenDone) {
            [self performSelector:@selector(onBlur:) withObject:view afterDelay:IDLE_INTERVAL];
        }
    }];
}

- (void)onBlur:(UIView *)view
{
    [self onBlur:view duration:0.6];
}

- (void)onBlur:(UIView *)view duration:(NSTimeInterval)duration
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];

    _isFocused = NO;
    [self updateSpeedLabel];
    [self resetLoopTimer];

    [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        view.transform = CGAffineTransformIdentity;
        view.alpha = HUD_INACTIVE_OPACITY;
    } completion:nil];
}

- (void)removeAllAnimations
{
    [_imguiView.layer removeAllAnimations];
    if (_contentView) {
        [_contentView.layer removeAllAnimations];
    }
}

- (void)resetGestureRecognizers
{
    if (!_contentView) {
        return;
    }
    for (UIGestureRecognizer *recognizer in _contentView.gestureRecognizers)
    {
        [recognizer setEnabled:NO];
        [recognizer setEnabled:YES];
    }
}

- (void)tapGestureRecognized:(UITapGestureRecognizer *)sender
{
    log_info(OS_LOG_DEFAULT, "TAPPED");
    if (!_isFocused) {
        [self onFocus:sender.view];
    } else {
        [self keepFocus:sender.view];
    }
}

- (void)cancelPreviousPerformRequestsWithTarget:(UIView *)view
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];
}

- (void)flashLockedViewWithDuration:(NSTimeInterval)duration
{
    (void)duration;
}

- (void)panGestureRecognized:(UIPanGestureRecognizer *)sender
{
    if (!_isFocused)
        return;

    HUDPresetPosition selectedMode = [self selectedModeForCurrentOrientation];
    BOOL isCentered = (selectedMode == HUDPresetPositionTopCenter || selectedMode == HUDPresetPositionTopCenterMost);

    if (isCentered || [self keepInPlace])
    {
        if (sender.state == UIGestureRecognizerStateBegan)
            [self cancelPreviousPerformRequestsWithTarget:sender.view];
        else if (sender.state == UIGestureRecognizerStateFailed || sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled)
            [self performSelector:@selector(onBlur:) withObject:sender.view afterDelay:IDLE_INTERVAL];

        if (sender.state == UIGestureRecognizerStateBegan)
        {
            if (!_notificationFeedbackGenerator)
                _notificationFeedbackGenerator = [[UINotificationFeedbackGenerator alloc] init];

            [_notificationFeedbackGenerator prepare];
            [_notificationFeedbackGenerator notificationOccurred:UINotificationFeedbackTypeError];

            [self flashLockedViewWithDuration:0.2];
        }

        return;
    }

    static CGFloat beginConstantY = 0.0;
    if (sender.state == UIGestureRecognizerStatePossible || sender.state == UIGestureRecognizerStateBegan)
    {
        beginConstantY = _topConstraint.constant;
        [self onFocus:sender.view scaleFactor:0.2 duration:0.1 beginFromInitialState:NO blurWhenDone:NO];
    }
    else
    {
        if (sender.state == UIGestureRecognizerStateChanged || sender.state == UIGestureRecognizerStateEnded)
        {
            CGFloat currentOffsetY = [sender translationInView:sender.view.superview].y;
            [_topConstraint setConstant:beginConstantY + currentOffsetY];
        }

        if (sender.state == UIGestureRecognizerStateEnded)
        {
            if (UIInterfaceOrientationIsLandscape(_orientation))
                [self setCurrentLandscapePositionY:_topConstraint.constant];
            else
                [self setCurrentPositionY:_topConstraint.constant];
        }

        if (sender.state != UIGestureRecognizerStateChanged)
        {
            [self onFocus:sender.view scaleFactor:0.1 duration:0.1 beginFromInitialState:NO blurWhenDone:NO];
            [self reloadUserDefaults];
        }
    }

    if (!_impactFeedbackGenerator)
    {
        _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }

    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled)
    {
        [_impactFeedbackGenerator prepare];
        [_impactFeedbackGenerator impactOccurred];
    }
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
    BOOL usesRotation = [self usesRotation];

    if (!usesRotation)
    {
        if (_imguiView) {
            _imguiView.alpha = (orientation == UIInterfaceOrientationPortrait) ? 1.0 : 0.0;
        }
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

    [self resetGestureRecognizers];

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:duration animations:^{
        [weakSelf.view setTransform:CGAffineTransformMakeRotation(orientationAngle(orientation))];
    } completion:^(BOOL finished) {
        [weakSelf.view setHidden:NO];
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end
