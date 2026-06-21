//
//  HUDMainWindow.mm
//  Demo 阶段关闭 secure context，避免 MTKView 拿不到 drawable
//

#import "HUDMainWindow.h"

@implementation HUDMainWindow

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
// Demo 需要可见+可点；正式版再按需打开穿透
- (BOOL)_ignoresHitTest { return NO; }
- (BOOL)_isSecure { return NO; }
- (BOOL)_shouldCreateContextAsSecure { return NO; }

@end
