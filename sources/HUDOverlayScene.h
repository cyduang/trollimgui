//
//  HUDOverlayScene.h
//  TrollSpeed
//
//  通过 FrontBoard 在桌面创建持久 overlay Scene。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HUDOverlayScene : NSObject

/// FrontBoard 提供的系统层承载视图
@property (nonatomic, readonly, nullable) UIView *hostView;

/// 创建并激活桌面 overlay Scene
- (BOOL)activate;

/// 停用并销毁 Scene
- (void)deactivate;

@end

NS_ASSUME_NONNULL_END
