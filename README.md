# TrollSpeed (TrollStore 版)

基于 [Lessica/TrollSpeed](https://github.com/Lessica/TrollSpeed) 最新上游代码重构的 **纯 TrollStore** 分支，已移除 ImGui 相关实验代码，恢复原版网速/FPS HUD 功能。

[![Build Release](https://github.com/cyduang/trollimgui/actions/workflows/build-release.yml/badge.svg)](https://github.com/cyduang/trollimgui/actions/workflows/build-release.yml)

## 功能

在状态栏下方显示 **上传/下载网速** 或 **FPS**，支持 TrollStore 持久化 HUD。

- 支持 iOS 14–17（TrollStore 支持的版本）
- 纯 TrollStore 安装，无需越狱
- 已移除 ImGui / FrontBoard 实验代码

## 构建

```bash
FINALPACKAGE=1 make package
```

产物位于 `packages/TrollSpeed_*.tipa`。

也可使用 Xcode：

```bash
./build.sh
```

## 安装

1. 用 **TrollStore** 安装 `.tipa`
2. 打开 App，点击「开启悬浮窗」
3. 退出 App 后 HUD 会保持在屏幕上

## 与上游差异

- `DISABLE_PATH_REDIRECTION=1`：不做 roothide/rootless 路径重定向
- CI 在 push 时自动构建 release

## License

MIT License — 见 [LICENSE](LICENSE)
