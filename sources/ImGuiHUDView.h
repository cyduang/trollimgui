//
//  ImGuiHUDView.h
//  TrollSpeed
//
//  ImGui CoreGraphics 渲染视图，用于 HUD 系统 overlay 层。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImGuiHUDView : UIView

+ (void)setMenuVisible:(BOOL)visible;
+ (BOOL)isMenuVisible;
+ (void)setShowDemoWindow:(BOOL)visible;

/// 恢复渲染循环（HUD 窗口显示后调用）
- (void)resumeRendering;

@end

NS_ASSUME_NONNULL_END
