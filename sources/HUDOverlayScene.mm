//
//  HUDOverlayScene.mm
//  TrollSpeed
//
//  参考 apibug / FrontBoardAppLauncher，用 FrontBoard 创建桌面可见 Scene。
//

#import "HUDOverlayScene.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import "UIKitFrontBoard+HUD.h"

@implementation HUDOverlayScene {
    FBScene *_scene;
    _UIScenePresenter *_presenter;
    UIView *_hostView;
}

@synthesize hostView = _hostView;

- (BOOL)activate
{
    if (_hostView) {
        return YES;
    }

    Class sceneManagerClass = HUDFBClass(FBSceneManager);
    Class definitionClass = HUDFBClass(FBSMutableSceneDefinition);
    Class parametersClass = HUDFBClass(FBSMutableSceneParameters);
    Class settingsClass = HUDFBClass(UIMutableApplicationSceneSettings);
    Class clientSettingsClass = HUDFBClass(UIMutableApplicationSceneClientSettings);
    Class sceneIdentityClass = HUDFBClass(FBSSceneIdentity);
    Class clientIdentityClass = HUDFBClass(FBSSceneClientIdentity);
    Class specificationClass = HUDFBClass(UIApplicationSceneSpecification);

    if (!sceneManagerClass || !definitionClass || !parametersClass || !settingsClass) {
        return NO;
    }

    FBSMutableSceneDefinition *definition = [definitionClass definition];
    definition.identity = [sceneIdentityClass identityForIdentifier:@"ch.xxtou.hudapp.overlay"];
    definition.clientIdentity = [clientIdentityClass localIdentity];
    definition.specification = [specificationClass specification];

    FBSMutableSceneParameters *parameters = [parametersClass parametersForSpecification:definition.specification];

    UIScreen *screen = UIScreen.mainScreen;
    UIMutableApplicationSceneSettings *settings = [[settingsClass alloc] init];
    settings.displayConfiguration = screen.displayConfiguration;
    settings.frame = screen._referenceBounds;
    settings.level = 10000010;
    settings.foreground = YES;
    settings.interfaceOrientation = UIInterfaceOrientationPortrait;
    settings.deviceOrientationEventsEnabled = YES;
    [settings.ignoreOcclusionReasons addObject:@"SystemApp"];
    parameters.settings = settings;

    UIMutableApplicationSceneClientSettings *clientSettings = [[clientSettingsClass alloc] init];
    clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
    clientSettings.statusBarStyle = 0;
    parameters.clientSettings = clientSettings;

    FBSceneManager *manager = [sceneManagerClass sharedInstance];
    _scene = [manager createSceneWithDefinition:definition initialParameters:parameters];
    if (!_scene) {
        return NO;
    }

    UIScenePresentationManager *presentationManager = [_scene uiPresentationManager];
    _presenter = [presentationManager createPresenterWithIdentifier:@"ch.xxtou.hudapp.presenter"];
    if (!_presenter) {
        _scene = nil;
        return NO;
    }

    [_presenter modifyPresentationContext:^(id context) {
        if ([context respondsToSelector:@selector(setAppearanceStyle:)]) {
            [(UIMutableScenePresentationContext *)context setAppearanceStyle:2];
        }
    }];
    [_presenter activate];

    _hostView = _presenter.presentationView;
    if (_hostView) {
        _hostView.frame = screen.bounds;
        _hostView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _hostView.backgroundColor = UIColor.clearColor;
        _hostView.opaque = NO;
    }

    return _hostView != nil;
}

- (void)deactivate
{
    if (_presenter) {
        [_presenter deactivate];
        if ([_presenter respondsToSelector:@selector(invalidate)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [_presenter performSelector:@selector(invalidate)];
#pragma clang diagnostic pop
        }
        _presenter = nil;
    }
    _scene = nil;
    _hostView = nil;
}

- (void)dealloc
{
    [self deactivate];
}

@end
