//
//  UIKitFrontBoard+HUD.h
//  TrollSpeed
//
//  FrontBoard / UIKit 私有 API，用于在桌面创建持久 overlay Scene。
//

#import <UIKit/UIKit.h>

#define HUDFBClass(NAME) NSClassFromString(@#NAME)

@interface FBSSceneIdentity : NSObject
+ (instancetype)identityForIdentifier:(NSString *)identifier;
@end

@interface FBSSceneClientIdentity : NSObject
+ (instancetype)localIdentity;
@end

@interface FBSSceneSpecification : NSObject
@end

@interface UIApplicationSceneSpecification : FBSSceneSpecification
@end

@interface FBSSceneParameters : NSObject
+ (instancetype)parametersForSpecification:(FBSSceneSpecification *)specification;
@end

@interface FBSMutableSceneParameters : FBSSceneParameters
@property (nonatomic, strong) id settings;
@property (nonatomic, strong) id clientSettings;
@end

@interface FBSMutableSceneDefinition : NSObject
@property (nonatomic, strong) FBSSceneIdentity *identity;
@property (nonatomic, strong) FBSSceneClientIdentity *clientIdentity;
@property (nonatomic, strong) FBSSceneSpecification *specification;
+ (instancetype)definition;
@end

@interface FBScene : NSObject
- (id)uiPresentationManager;
@end

@interface FBSceneManager : NSObject
+ (instancetype)sharedInstance;
- (FBScene *)createSceneWithDefinition:(FBSMutableSceneDefinition *)definition
                     initialParameters:(FBSMutableSceneParameters *)parameters;
@end

@interface UIScenePresentationManager : NSObject
- (id)createPresenterWithIdentifier:(NSString *)identifier;
@end

@interface _UIScenePresentationView : UIView
@end

@interface _UIScenePresenter : NSObject
@property (nonatomic, readonly) _UIScenePresentationView *presentationView;
- (void)modifyPresentationContext:(void (^)(id context))block;
- (void)activate;
@end

@interface UIMutableScenePresentationContext : NSObject
@property (nonatomic, assign) NSUInteger appearanceStyle;
@end

@interface UIMutableApplicationSceneSettings : NSObject
@property (nonatomic, assign) BOOL foreground;
@property (nonatomic, assign) NSInteger level;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) NSInteger interfaceOrientation;
@property (nonatomic, assign) BOOL deviceOrientationEventsEnabled;
- (id)displayConfiguration;
- (void)setDisplayConfiguration:(id)displayConfiguration;
- (NSMutableSet *)ignoreOcclusionReasons;
@end

@interface UIMutableApplicationSceneClientSettings : NSObject
@property (nonatomic, assign) NSInteger interfaceOrientation;
@property (nonatomic, assign) NSInteger statusBarStyle;
@end

@interface UIScreen (HUDFrontBoard)
- (id)displayConfiguration;
- (CGRect)_referenceBounds;
@end
