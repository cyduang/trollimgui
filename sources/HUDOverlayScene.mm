//
//  HUDOverlayScene.mm
//  TrollSpeed
//
//  通过 objc/runtime 动态调用 FrontBoard，无需链接 FrontBoard.framework（CI/Xcode SDK 无此库）。
//

#import "HUDOverlayScene.h"

#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "UIKitFrontBoard+HUD.h"

static BOOL HUDLoadFrontBoardFramework(void)
{
    static BOOL loaded = NO;
    static BOOL ok = NO;
    if (loaded) {
        return ok;
    }
    loaded = YES;

    void *handle = dlopen("/System/Library/PrivateFrameworks/FrontBoard.framework/FrontBoard", RTLD_NOW);
    if (!handle) {
        handle = dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
    }
    ok = (handle != NULL);
    return ok;
}

@implementation HUDOverlayScene {
    id _scene;
    id _presenter;
    UIView *_hostView;
}

@synthesize hostView = _hostView;

- (BOOL)activate
{
    if (_hostView) {
        return YES;
    }

    if (!HUDLoadFrontBoardFramework()) {
        return NO;
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

    id definition = [definitionClass definition];
    [definition setValue:[sceneIdentityClass identityForIdentifier:@"ch.xxtou.hudapp.overlay"] forKey:@"identity"];
    [definition setValue:[clientIdentityClass localIdentity] forKey:@"clientIdentity"];
    [definition setValue:[(id)specificationClass specification] forKey:@"specification"];

    id specification = [definition valueForKey:@"specification"];
    id parameters = [parametersClass parametersForSpecification:specification];

    UIScreen *screen = UIScreen.mainScreen;
    id settings = [[settingsClass alloc] init];
    id displayConfig = ((id (*)(id, SEL))objc_msgSend)((id)screen, @selector(displayConfiguration));
    ((void (*)(id, SEL, id))objc_msgSend)(settings, @selector(setDisplayConfiguration:), displayConfig);
    CGRect bounds = ((CGRect (*)(id, SEL))objc_msgSend)((id)screen, @selector(_referenceBounds));
    ((void (*)(id, SEL, CGRect))objc_msgSend)(settings, @selector(setFrame:), bounds);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(settings, @selector(setLevel:), (NSInteger)10000010);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(settings, @selector(setForeground:), YES);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(settings, @selector(setInterfaceOrientation:), (NSInteger)UIInterfaceOrientationPortrait);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(settings, @selector(setDeviceOrientationEventsEnabled:), YES);
    [((NSMutableSet *(*)(id, SEL))objc_msgSend)(settings, @selector(ignoreOcclusionReasons)) addObject:@"SystemApp"];
    [parameters setValue:settings forKey:@"settings"];

    id clientSettings = [[clientSettingsClass alloc] init];
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(clientSettings, @selector(setInterfaceOrientation:), (NSInteger)UIInterfaceOrientationPortrait);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(clientSettings, @selector(setStatusBarStyle:), (NSInteger)0);
    [parameters setValue:clientSettings forKey:@"clientSettings"];

    id manager = ((id (*)(id, SEL))objc_msgSend)(sceneManagerClass, @selector(sharedInstance));
    _scene = ((id (*)(id, SEL, id, id))objc_msgSend)(manager, @selector(createSceneWithDefinition:initialParameters:), definition, parameters);
    if (!_scene) {
        return NO;
    }

    id presentationManager = ((id (*)(id, SEL))objc_msgSend)(_scene, @selector(uiPresentationManager));
    _presenter = ((id (*)(id, SEL, id))objc_msgSend)(presentationManager, @selector(createPresenterWithIdentifier:), @"ch.xxtou.hudapp.presenter");
    if (!_presenter) {
        _scene = nil;
        return NO;
    }

    void (^modifyBlock)(id) = ^(id context) {
        if ([context respondsToSelector:@selector(setAppearanceStyle:)]) {
            [context setValue:@2 forKey:@"appearanceStyle"];
        }
    };
    ((void (*)(id, SEL, void (^)(id)))objc_msgSend)(_presenter, @selector(modifyPresentationContext:), modifyBlock);
    ((void (*)(id, SEL))objc_msgSend)(_presenter, @selector(activate));

    _hostView = ((UIView *(*)(id, SEL))objc_msgSend)(_presenter, @selector(presentationView));
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
        if ([_presenter respondsToSelector:@selector(deactivate)]) {
            ((void (*)(id, SEL))objc_msgSend)(_presenter, @selector(deactivate));
        }
        if ([_presenter respondsToSelector:@selector(invalidate)]) {
            ((void (*)(id, SEL))objc_msgSend)(_presenter, @selector(invalidate));
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
