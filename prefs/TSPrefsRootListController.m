#import <Foundation/Foundation.h>
#import <Preferences/PSSpecifier.h>

#import <rootless.h>

#import "TSPrefsRootListController.h"

// libroot 的 ROOT_PATH_NS 需要 NSString，不能传 C 字符串格式字面量
static NSString *TSPrefsPlistPathForSpecifier(PSSpecifier *specifier) {
    NSString *containerPath =
        [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    return ROOT_PATH_NS([NSString stringWithFormat:@"%@/Preferences/%@.plist", containerPath,
                                                   specifier.properties[@"defaults"]]);
}

@implementation TSPrefsRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = TSPrefsPlistPathForSpecifier(specifier);
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = TSPrefsPlistPathForSpecifier(specifier);
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    [settings setObject:value forKey:specifier.properties[@"key"]];
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL,
                                             YES);
    }
}

- (void)resetToDefaults:(PSSpecifier *)specifier {
    NSString *path = TSPrefsPlistPathForSpecifier(specifier);
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL,
                                             YES);
    }
    [self reloadSpecifiers];
}

@end
