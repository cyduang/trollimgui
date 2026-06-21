//
//  HUDMainWindow.mm
//  TrollSpeed
//

#import "HUDMainWindow.h"
#import "HUDRootViewController.h"
#import "ImGuiHUDView.h"

@implementation HUDMainWindow

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_ignoresHitTest
{
    if (![ImGuiHUDView isMenuVisible]) {
        return YES;
    }
    return [HUDRootViewController passthroughMode];
}
- (BOOL)_isSecure { return YES; }
- (BOOL)_shouldCreateContextAsSecure { return YES; }
- (BOOL)isOpaque { return NO; }

@end
