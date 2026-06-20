//
//  ImGuiHUDView.h
//  TrollSpeed
//
//  ImGui Metal 渲染视图，用于 HUD 叠加层显示。
//

#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImGuiHUDView : MTKView

/// 切换 ImGui 菜单显示/隐藏
+ (void)setMenuVisible:(BOOL)visible;

/// 菜单当前是否可见
+ (BOOL)isMenuVisible;

@end

NS_ASSUME_NONNULL_END
