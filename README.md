# 巨魔 ImGui HUD（和平精英）

基于 TrollSpeed HUD 框架 + ImGui Metal 渲染，通过 Theos 构建 TrollStore `.tipa`。

## 构建

### 本地（macOS + Theos）

```bash
chmod +x get-version.sh gen-control.sh
./gen-control.sh
FINALPACKAGE=1 make package
```

产物：`packages/TrollSpeed_<version>.tipa`

### GitHub Actions

推送代码到 GitHub 后自动构建，workflow 位于 **`.github/workflows/build-release.yml`**（注意是 `.github` 不是 `_github`）。

> Windows 资源管理器默认隐藏以 `.` 开头的文件夹。若看不到 `.github`，请在「查看」中勾选「隐藏的项目」。

打 tag（如 `v1.0.0`）会额外发布到 GitHub Releases。

## 安装

使用 **TrollStore** 安装 `.tipa`，需要巨魔环境提供的 root HUD 权限。

## 已知限制

- Xcode `build.sh` 工程中部分文件仍引用不存在的 `ImGui 1.91.5` 路径，**请优先使用 Theos 构建**
- `memory_pressure` 为可选子模块，CI 使用 `FINALPACKAGE=1` 不会依赖它
- HUD 使用 Metal 渲染，需设备支持 Metal

## License

MIT License
