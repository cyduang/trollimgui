//
//  ImGuiHUDView.mm
//  TrollSpeed
//
//  使用 CoreGraphics 软件渲染 ImGui，兼容系统 overlay / FrontBoard Scene。
//

#import "ImGuiHUDView.h"

#import <QuartzCore/QuartzCore.h>

#import "imgui.h"
#import "imgui_impl_ios_cg.h"

@interface ImGuiHUDView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CGContextRef bitmapContext;
@property (nonatomic, assign) int bufferWidth;
@property (nonatomic, assign) int bufferHeight;
@end

@implementation ImGuiHUDView

static BOOL s_menuVisible = YES;
static BOOL s_showDemoWindow = NO;
static BOOL s_showHelloWindow = YES;
static BOOL s_imguiInitialized = NO;

+ (void)setMenuVisible:(BOOL)visible
{
    s_menuVisible = visible;
    s_showHelloWindow = visible;
}

+ (BOOL)isMenuVisible
{
    return s_menuVisible;
}

+ (void)setShowDemoWindow:(BOOL)visible
{
    s_showDemoWindow = visible;
}

- (void)setupImGuiIfNeeded
{
    if (s_imguiInitialized) {
        return;
    }

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.IniFilename = nullptr;
    ImGui::StyleColorsDark();
    io.Fonts->AddFontDefault();
    io.Fonts->Build();
    ImGui_ImplIOS_Init();
    s_imguiInitialized = YES;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.layer.opaque = NO;
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        self.contentMode = UIViewContentModeRedraw;

        [self setupImGuiIfNeeded];

        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLink:)];
        _displayLink.preferredFramesPerSecond = 60;
        [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)dealloc
{
    [_displayLink invalidate];
    [self releaseBitmapContext];
    if (s_imguiInitialized) {
        ImGui_ImplIOS_Shutdown();
        ImGui::DestroyContext();
        s_imguiInitialized = NO;
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    self.displayLink.paused = (self.window == nil);
    if (self.window) {
        self.contentScaleFactor = self.window.screen.scale;
        [self ensureBitmapContext];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self ensureBitmapContext];
}

- (void)releaseBitmapContext
{
    if (_bitmapContext) {
        CGContextRelease(_bitmapContext);
        _bitmapContext = nullptr;
    }
    _bufferWidth = 0;
    _bufferHeight = 0;
}

- (void)ensureBitmapContext
{
    CGFloat scale = self.window.screen.scale ?: UIScreen.mainScreen.scale;
    int width = (int)(self.bounds.size.width * scale);
    int height = (int)(self.bounds.size.height * scale);
    if (width < 2 || height < 2) {
        return;
    }
    if (_bitmapContext && width == _bufferWidth && height == _bufferHeight) {
        return;
    }

    [self releaseBitmapContext];
    _bufferWidth = width;
    _bufferHeight = height;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    _bitmapContext = CGBitmapContextCreate(
        nullptr,
        width,
        height,
        8,
        width * 4,
        colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
}

#pragma mark - 触摸

- (void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    if (!anyTouch) {
        return;
    }

    CGPoint touchLocation = [anyTouch locationInView:self];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2((float)touchLocation.x, (float)touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches) {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
            hasActiveTouch = YES;
            break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!s_menuVisible) {
        return nil;
    }
    return [super hitTest:point withEvent:event];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

#pragma mark - 渲染

- (void)onDisplayLink:(CADisplayLink *)link
{
    (void)link;
    if (!s_menuVisible) {
        self.layer.contents = nil;
        return;
    }
    [self renderFrame];
}

- (void)drawCustomOverlayShapes
{
    ImDrawList *drawList = ImGui::GetBackgroundDrawList();
    if (!drawList) {
        return;
    }

    const ImVec2 center(self.bounds.size.width * 0.5f, self.bounds.size.height * 0.5f);
    const float radius = fminf(self.bounds.size.width, self.bounds.size.height) * 0.22f;
    const int sides = 10;
    ImVec2 points[10];
    for (int i = 0; i < sides; ++i) {
        const float angle = ((float)i / (float)sides) * IM_PI * 2.0f - IM_PI * 0.5f;
        points[i] = ImVec2(center.x + cosf(angle) * radius, center.y + sinf(angle) * radius);
    }
    drawList->AddConvexPolyFilled(points, sides, IM_COL32(255, 0, 0, 40));
    drawList->AddPolyline(points, sides, IM_COL32(255, 0, 0, 220), ImDrawFlags_Closed, 3.0f);
    drawList->AddText(ImVec2(center.x - 70.0f, center.y - 8.0f), IM_COL32(255, 255, 255, 255), "TrollImGui HUD");
}

- (void)buildImGuiUI
{
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2((float)self.bounds.size.width, (float)self.bounds.size.height);
    CGFloat scale = self.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2((float)scale, (float)scale);
    io.DeltaTime = 1.0f / 60.0f;

    self.userInteractionEnabled = s_menuVisible;

    ImGui_ImplIOS_NewFrame();
    ImGui::NewFrame();

    if (s_menuVisible) {
        ImGui::SetNextWindowPos(ImVec2(40.0f, 120.0f), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(360.0f, 280.0f), ImGuiCond_FirstUseEver);

        if (ImGui::Begin("Hello, world!", &s_showHelloWindow)) {
            ImGui::Text("ImGui 桌面 HUD");
            ImGui::Separator();
            ImGui::Text("平均 %.3f ms/帧 (%.1f FPS)", 1000.0f / io.Framerate, io.Framerate);
            ImGui::Checkbox("显示 ImGui Demo 窗口", &s_showDemoWindow);

            static float sliderValue = 0.5f;
            ImGui::SliderFloat("示例滑块", &sliderValue, 0.0f, 1.0f);

            static int counter = 0;
            if (ImGui::Button("Button")) {
                counter++;
            }
            ImGui::SameLine();
            if (ImGui::Button("Button1")) {
                counter += 10;
            }
            ImGui::Text("counter = %d", counter);
            ImGui::End();
        }

        if (s_showDemoWindow) {
            ImGui::ShowDemoWindow(&s_showDemoWindow);
        }

        if (!s_showHelloWindow) {
            s_menuVisible = NO;
        }
    }

    [self drawCustomOverlayShapes];
    ImGui::Render();
}

- (void)renderFrame
{
    if (self.bounds.size.width < 1 || self.bounds.size.height < 1) {
        return;
    }

    [self ensureBitmapContext];
    if (!_bitmapContext) {
        return;
    }

    [self buildImGuiUI];

    ImDrawData *drawData = ImGui::GetDrawData();
    if (!drawData || !drawData->Valid) {
        return;
    }

    ImGui_ImplIOS_RenderDrawData(drawData, _bitmapContext, _bufferWidth, _bufferHeight);

    CGImageRef image = CGBitmapContextCreateImage(_bitmapContext);
    if (!image) {
        return;
    }

    self.layer.contents = (__bridge id)image;
    self.layer.contentsGravity = kCAGravityResize;
    CGImageRelease(image);
}

@end
