//
//  HUDRootViewController.mm
//  ImGui 桌面悬浮 Demo：仅显示 Hello World，不依赖游戏进程
//

#import "HUDRootViewController.h"

#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>

#import "imgui.h"
#import "imgui_impl_metal.h"

@interface HUDRootViewController () <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) id<MTLDevice> metalDevice;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) CFTimeInterval lastFrameTime;
@end

@implementation HUDRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    self.metalDevice = MTLCreateSystemDefaultDevice();
    NSAssert(self.metalDevice != nil, @"Metal is required for ImGui HUD");

    self.mtkView = [[MTKView alloc] initWithFrame:self.view.bounds];
    self.mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mtkView.device = self.metalDevice;
    self.mtkView.delegate = self;
    self.mtkView.opaque = NO;
    self.mtkView.layer.opaque = NO;
    self.mtkView.backgroundColor = UIColor.clearColor;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.paused = NO;
    self.mtkView.enableSetNeedsDisplay = NO;
    self.mtkView.preferredFramesPerSecond = 60;
    self.mtkView.framebufferOnly = NO;
    self.mtkView.userInteractionEnabled = YES;
    [self.view addSubview:self.mtkView];

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO &io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    ImGui_ImplMetal_Init(self.metalDevice);
    self.commandQueue = [self.metalDevice newCommandQueue];
    self.lastFrameTime = CACurrentMediaTime();
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.mtkView.frame = self.view.bounds;
}

- (void)dealloc {
    ImGui_ImplMetal_Shutdown();
    ImGui::DestroyContext();
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

- (void)drawInMTKView:(MTKView *)view {
    CFTimeInterval now = CACurrentMediaTime();
    float delta = (float)(now - self.lastFrameTime);
    self.lastFrameTime = now;
    if (delta <= 0.0f) {
        delta = 1.0f / 60.0f;
    }

    ImGuiIO &io = ImGui::GetIO();
    CGSize drawableSize = view.drawableSize;
    if (drawableSize.width < 1.0 || drawableSize.height < 1.0) {
        CGFloat scale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
        drawableSize = CGSizeMake(view.bounds.size.width * scale, view.bounds.size.height * scale);
    }
    io.DisplaySize = ImVec2((float)drawableSize.width, (float)drawableSize.height);
    io.DisplayFramebufferScale = ImVec2(1.0f, 1.0f);
    io.DeltaTime = delta;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor == nil) {
        [commandBuffer commit];
        return;
    }

    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui::NewFrame();

    ImGui::Begin("TrollImGui Demo");
    ImGui::Text("Hello World");
    ImGui::Text("Desktop ImGui overlay is active.");
    ImGui::End();

    ImDrawList *foreground = ImGui::GetForegroundDrawList();
    foreground->AddText(ImVec2(40.0f, 40.0f), IM_COL32(0, 255, 0, 255), "Hello World");

    ImGui::Render();

    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, encoder);
    [encoder endEncoding];

    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end
