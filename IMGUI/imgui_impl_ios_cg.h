//
//  imgui_impl_ios_cg.h
//  TrollSpeed
//
//  ImGui CoreGraphics 软件渲染后端，适用于系统 overlay 安全图层。
//

#pragma once

#include "imgui.h"

struct CGContext;

bool ImGui_ImplIOS_Init(void);
void ImGui_ImplIOS_Shutdown(void);
void ImGui_ImplIOS_NewFrame(void);
void ImGui_ImplIOS_RenderDrawData(ImDrawData *draw_data, CGContextRef context, int width, int height);
