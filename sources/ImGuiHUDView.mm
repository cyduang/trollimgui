//
//  ImGuiHUDView.mm
//  TrollSpeed
//
//  基于 Metal + MTKView 的 ImGui HUD 渲染，参考 AOV-MENU-IMGUI-IOS-NONJB 项目。
//

#import "ImGuiHUDView.h"

#import <Metal/Metal.h>

#import "imgui.h"
#import "imgui_impl_metal.h"

@interface ImGuiHUDView () <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@end

@implementation ImGuiHUDView

static BOOL s_menuVisible = YES;
static BOOL s_showDemoWindow = YES;
static BOOL s_showHelloWindow = YES;

+ (void)setMenuVisible:(BOOL)visible
{
    s_menuVisible = visible;
}

+ (BOOL)isMenuVisible
{
    return s_menuVisible;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self = [super initWithFrame:frame device:device];
    if (self) {
        if (!device) {
            return nil;
        }

        _commandQueue = [device newCommandQueue];

        self.delegate = self;
        self.clearColor = MTLClearColorMake(0, 0, 0, 0);
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.layer.opaque = NO;
        self.enableSetNeedsDisplay = NO;
        self.paused = NO;
        self.preferredFramesPerSecond = 60;

        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO &io = ImGui::GetIO();
        (void)io;
        io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

        ImGui::StyleColorsDark();
        ImGui_ImplMetal_Init(device);
    }
    return self;
}

- (void)dealloc
{
    ImGui_ImplMetal_Shutdown();
    ImGui::DestroyContext();
}

#pragma mark - 触摸输入

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

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    (void)view;
    (void)size;
}

- (void)drawInMTKView:(MTKView *)view
{
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2((float)view.bounds.size.width, (float)view.bounds.size.height);

    CGFloat scale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2((float)scale, (float)scale);
    io.DeltaTime = 1.0f / (float)(view.preferredFramesPerSecond ?: 60);

    self.userInteractionEnabled = s_menuVisible;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) {
        return;
    }

    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui::NewFrame();

    if (s_menuVisible) {
        CGFloat centerX = (view.bounds.size.width - 400.0) / 2.0;
        CGFloat centerY = (view.bounds.size.height - 300.0) / 2.0;
        ImGui::SetNextWindowPos(ImVec2((float)centerX, (float)centerY), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(420.0f, 320.0f), ImGuiCond_FirstUseEver);

        if (ImGui::Begin("TrollImGui HUD", &s_showHelloWindow)) {
            ImGui::Text("ImGui 示例窗口");
            ImGui::Separator();
            ImGui::Text("应用平均 %.3f ms/帧 (%.1f FPS)", 1000.0f / io.Framerate, io.Framerate);
            ImGui::Checkbox("显示 ImGui Demo 窗口", &s_showDemoWindow);

            static float sliderValue = 0.5f;
            ImGui::SliderFloat("示例滑块", &sliderValue, 0.0f, 1.0f);

            static int counter = 0;
            if (ImGui::Button("点击计数")) {
                counter++;
            }
            ImGui::SameLine();
            ImGui::Text("计数 = %d", counter);

            ImGui::End();
        }

        if (s_showDemoWindow) {
            ImGui::ShowDemoWindow(&s_showDemoWindow);
        }

        if (!s_showHelloWindow) {
            s_menuVisible = NO;
        }
    }

    ImGui::Render();
    ImDrawData *drawData = ImGui::GetDrawData();
    ImGui_ImplMetal_RenderDrawData(drawData, commandBuffer, renderEncoder);

    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

@end
