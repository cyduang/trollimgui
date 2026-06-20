//
//  imgui_impl_ios_cg.mm
//  TrollSpeed
//
//  ImGui CPU 渲染到 CoreGraphics 位图，可在安全 overlay 窗口上显示。
//

#include "imgui_impl_ios_cg.h"

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

static unsigned char *g_FontPixels = nullptr;
static int g_FontWidth = 0;
static int g_FontHeight = 0;

static inline uint32_t BlendPixel(uint32_t dst, uint32_t src)
{
    const uint32_t sa = (src >> 24) & 0xFF;
    if (sa == 0) {
        return dst;
    }
    if (sa == 255) {
        return src;
    }

    const uint32_t sr = (src >> 16) & 0xFF;
    const uint32_t sg = (src >> 8) & 0xFF;
    const uint32_t sb = src & 0xFF;

    const uint32_t da = (dst >> 24) & 0xFF;
    const uint32_t dr = (dst >> 16) & 0xFF;
    const uint32_t dg = (dst >> 8) & 0xFF;
    const uint32_t db = dst & 0xFF;

    const uint32_t invA = 255 - sa;
    const uint32_t outA = sa + ((da * invA) + 127) / 255;
    const uint32_t outR = (sr * sa + dr * invA + 127) / 255;
    const uint32_t outG = (sg * sa + dg * invA + 127) / 255;
    const uint32_t outB = (sb * sa + db * invA + 127) / 255;

    return (outA << 24) | (outR << 16) | (outG << 8) | outB;
}

static void RasterizeTriangle(
    uint32_t *pixels,
    int width,
    int height,
    ImVec2 p0,
    ImVec2 p1,
    ImVec2 p2,
    ImVec2 uv0,
    ImVec2 uv1,
    ImVec2 uv2,
    uint32_t col0,
    uint32_t col1,
    uint32_t col2,
    ImTextureID textureId,
    int texWidth,
    int texHeight,
    const unsigned char *texData,
    int clipX0,
    int clipY0,
    int clipX1,
    int clipY1)
{
    const float area = (p1.x - p0.x) * (p2.y - p0.y) - (p2.x - p0.x) * (p1.y - p0.y);
    if (fabsf(area) < 0.5f) {
        return;
    }
    const float invArea = 1.0f / area;

    const int minX = (int)fmaxf(clipX0, floorf(fminf(fminf(p0.x, p1.x), p2.x)));
    const int maxX = (int)fminf(clipX1, ceilf(fmaxf(fmaxf(p0.x, p1.x), p2.x)));
    const int minY = (int)fmaxf(clipY0, floorf(fminf(fminf(p0.y, p1.y), p2.y)));
    const int maxY = (int)fminf(clipY1, ceilf(fmaxf(fmaxf(p0.y, p1.y), p2.y)));

    const uint8_t *texBytes = texData;
    (void)textureId;

    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            const float w0 = ((p1.x - p0.x) * (y - p0.y) - (p1.y - p0.y) * (x - p0.x)) * invArea;
            const float w1 = ((p2.x - p1.x) * (y - p1.y) - (p2.y - p1.y) * (x - p1.x)) * invArea;
            const float w2 = 1.0f - w0 - w1;
            if (w0 < 0.0f || w1 < 0.0f || w2 < 0.0f) {
                continue;
            }

            uint32_t color = 0;
            if (texBytes && texWidth > 0 && texHeight > 0) {
                const float u = uv0.x * w0 + uv1.x * w1 + uv2.x * w2;
                const float v = uv0.y * w0 + uv1.y * w1 + uv2.y * w2;
                const int tx = (int)(u * texWidth) % texWidth;
                const int ty = (int)(v * texHeight) % texHeight;
                const int texIndex = (ty * texWidth + tx) * 4;
                const uint8_t tr = texBytes[texIndex + 0];
                const uint8_t tg = texBytes[texIndex + 1];
                const uint8_t tb = texBytes[texIndex + 2];
                const uint8_t ta = texBytes[texIndex + 3];

                const uint32_t c0 = col0;
                const uint32_t c1 = col1;
                const uint32_t c2 = col2;
                const float rf = ((c0 >> IM_COL32_R_SHIFT) & 0xFF) * w0 + ((c1 >> IM_COL32_R_SHIFT) & 0xFF) * w1 + ((c2 >> IM_COL32_R_SHIFT) & 0xFF) * w2;
                const float gf = ((c0 >> IM_COL32_G_SHIFT) & 0xFF) * w0 + ((c1 >> IM_COL32_G_SHIFT) & 0xFF) * w1 + ((c2 >> IM_COL32_G_SHIFT) & 0xFF) * w2;
                const float bf = ((c0 >> IM_COL32_B_SHIFT) & 0xFF) * w0 + ((c1 >> IM_COL32_B_SHIFT) & 0xFF) * w1 + ((c2 >> IM_COL32_B_SHIFT) & 0xFF) * w2;
                const float af = ((c0 >> IM_COL32_A_SHIFT) & 0xFF) * w0 + ((c1 >> IM_COL32_A_SHIFT) & 0xFF) * w1 + ((c2 >> IM_COL32_A_SHIFT) & 0xFF) * w2;

                const uint8_t r = (uint8_t)((tr * rf) / 255.0f);
                const uint8_t g = (uint8_t)((tg * gf) / 255.0f);
                const uint8_t b = (uint8_t)((tb * bf) / 255.0f);
                const uint8_t a = (uint8_t)((ta * af) / 255.0f);
                color = ((uint32_t)a << 24) | ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
            } else {
                const float rf = ((col0 >> IM_COL32_R_SHIFT) & 0xFF) * w0 + ((col1 >> IM_COL32_R_SHIFT) & 0xFF) * w1 + ((col2 >> IM_COL32_R_SHIFT) & 0xFF) * w2;
                const float gf = ((col0 >> IM_COL32_G_SHIFT) & 0xFF) * w0 + ((col1 >> IM_COL32_G_SHIFT) & 0xFF) * w1 + ((col2 >> IM_COL32_G_SHIFT) & 0xFF) * w2;
                const float bf = ((col0 >> IM_COL32_B_SHIFT) & 0xFF) * w0 + ((col1 >> IM_COL32_B_SHIFT) & 0xFF) * w1 + ((col2 >> IM_COL32_B_SHIFT) & 0xFF) * w2;
                const float af = ((col0 >> IM_COL32_A_SHIFT) & 0xFF) * w0 + ((col1 >> IM_COL32_A_SHIFT) & 0xFF) * w1 + ((col2 >> IM_COL32_A_SHIFT) & 0xFF) * w2;
                color = ((uint32_t)af << 24) | ((uint32_t)rf << 16) | ((uint32_t)gf << 8) | (uint32_t)bf;
            }

            if (((color >> 24) & 0xFF) == 0) {
                continue;
            }

            if (x >= 0 && y >= 0 && x < width && y < height) {
                uint32_t *dst = &pixels[y * width + x];
                *dst = BlendPixel(*dst, color);
            }
        }
    }
}

bool ImGui_ImplIOS_Init(void)
{
    ImGuiIO &io = ImGui::GetIO();
    io.BackendRendererName = "imgui_impl_ios_cg";
    io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset;

    unsigned char *pixels = nullptr;
    int texWidth = 0;
    int texHeight = 0;
    io.Fonts->GetTexDataAsRGBA32(&pixels, &texWidth, &texHeight);
    if (!pixels || texWidth <= 0 || texHeight <= 0) {
        return false;
    }

    const size_t dataSize = (size_t)texWidth * (size_t)texHeight * 4;
    unsigned char *copiedPixels = (unsigned char *)malloc(dataSize);
    if (!copiedPixels) {
        return false;
    }
    memcpy(copiedPixels, pixels, dataSize);
    g_FontPixels = copiedPixels;
    g_FontWidth = texWidth;
    g_FontHeight = texHeight;

    io.Fonts->SetTexID((ImTextureID)(intptr_t)1);
    return true;
}

void ImGui_ImplIOS_Shutdown(void)
{
    if (g_FontPixels) {
        free(g_FontPixels);
        g_FontPixels = nullptr;
    }
    g_FontWidth = 0;
    g_FontHeight = 0;
    ImGuiIO &io = ImGui::GetIO();
    io.Fonts->SetTexID(nullptr);
}

void ImGui_ImplIOS_NewFrame(void)
{
}

void ImGui_ImplIOS_RenderDrawData(ImDrawData *draw_data, CGContextRef context, int width, int height)
{
    if (!draw_data || !draw_data->Valid || !context || width <= 0 || height <= 0) {
        return;
    }

    uint32_t *pixels = (uint32_t *)CGBitmapContextGetData(context);
    if (!pixels) {
        return;
    }

    memset(pixels, 0, (size_t)width * (size_t)height * sizeof(uint32_t));

    const ImVec2 clipOff = draw_data->DisplayPos;
    const ImVec2 clipScale = draw_data->FramebufferScale;

    for (int n = 0; n < draw_data->CmdListsCount; ++n) {
        const ImDrawList *cmdList = draw_data->CmdLists[n];
        const ImDrawVert *vtxBuffer = cmdList->VtxBuffer.Data;
        const ImDrawIdx *idxBuffer = cmdList->IdxBuffer.Data;

        for (int cmd_i = 0; cmd_i < cmdList->CmdBuffer.Size; ++cmd_i) {
            const ImDrawCmd *pcmd = &cmdList->CmdBuffer[cmd_i];
            if (pcmd->UserCallback) {
                if (pcmd->UserCallback != ImDrawCallback_ResetRenderState) {
                    pcmd->UserCallback(cmdList, pcmd);
                }
                continue;
            }

            const ImVec4 clipRect(
                (pcmd->ClipRect.x - clipOff.x) * clipScale.x,
                (pcmd->ClipRect.y - clipOff.y) * clipScale.y,
                (pcmd->ClipRect.z - clipOff.x) * clipScale.x,
                (pcmd->ClipRect.w - clipOff.y) * clipScale.y);

            const int clipX0 = (int)clipRect.x;
            const int clipY0 = (int)clipRect.y;
            const int clipX1 = (int)clipRect.z;
            const int clipY1 = (int)clipRect.w;

            const ImTextureID texId = pcmd->TextureId;
            const unsigned char *texBytes = nullptr;
            int texWidth = 0;
            int texHeight = 0;
            if (texId == (ImTextureID)(intptr_t)1) {
                texBytes = g_FontPixels;
                texWidth = g_FontWidth;
                texHeight = g_FontHeight;
            }
            (void)texId;

            for (unsigned int i = 0; i + 2 < pcmd->ElemCount; i += 3) {
                const ImDrawIdx idx0 = idxBuffer[pcmd->IdxOffset + i];
                const ImDrawIdx idx1 = idxBuffer[pcmd->IdxOffset + i + 1];
                const ImDrawIdx idx2 = idxBuffer[pcmd->IdxOffset + i + 2];

                const ImDrawVert &v0 = vtxBuffer[idx0];
                const ImDrawVert &v1 = vtxBuffer[idx1];
                const ImDrawVert &v2 = vtxBuffer[idx2];

                RasterizeTriangle(
                    pixels,
                    width,
                    height,
                    ImVec2(v0.pos.x, v0.pos.y),
                    ImVec2(v1.pos.x, v1.pos.y),
                    ImVec2(v2.pos.x, v2.pos.y),
                    ImVec2(v0.uv.x, v0.uv.y),
                    ImVec2(v1.uv.x, v1.uv.y),
                    ImVec2(v2.uv.x, v2.uv.y),
                    v0.col,
                    v1.col,
                    v2.col,
                    texId,
                    texWidth,
                    texHeight,
                    texBytes,
                    clipX0,
                    clipY0,
                    clipX1,
                    clipY1);
            }
        }
    }
}
