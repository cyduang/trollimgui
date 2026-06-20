//
//  HUDMainWindow.mm
//  TrollSpeed
//
//  Created by Lessica on 2024/1/24.
//

#import "HUDMainWindow.h"
#import "HUDRootViewController.h"

@implementation HUDMainWindow

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_ignoresHitTest { return [HUDRootViewController passthroughMode]; }
- (BOOL)_isSecure { return NO; }
- (BOOL)_shouldCreateContextAsSecure { return NO; }
- (BOOL)isOpaque { return NO; }

@end
