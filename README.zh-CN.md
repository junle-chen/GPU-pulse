# GPU Pulse

[English](README.md) | [简体中文](README.zh-CN.md)

<p align="center">
  <img src="assets/gpu-pulse-icon.png" width="112" alt="GPU Pulse 图标">
</p>

GPU Pulse 是一款简洁的原生 macOS 菜单栏应用，用于查看多台服务器的 GPU
显存占用和利用率。应用直接使用你已有的 SSH 配置连接服务器，不依赖托管后端，
也不会把监控数据上传到其他服务。

## 图片展示

### 应用图标

<p align="center">
  <img src="assets/gpu-pulse-icon.png" width="220" alt="GPU Pulse 应用图标">
</p>

图标中的多条横向进度条代表一组 GPU。颜色从绿色过渡到红色，与面板中的
GPU 利用率颜色保持一致；深色圆角背景可以保证图标在 Dock、Finder 和 macOS
应用列表中清晰可见。

### 监控面板

![显示四台通用服务器的 GPU Pulse 面板](assets/gpu-pulse-dashboard.png)

截图只使用 `SERVER 1–4` 这类通用名称。真实 SSH 别名仅保存在本机
`servers.json` 中，不会写入仓库图片或应用二进制。

## 面板信息

- 四台服务器以紧凑的 2×2 网格显示。
- 每一行代表一张 GPU：进度条长度表示显存占用，绿色、黄色和红色表示 GPU
  利用率。
- `MINE` 用蓝紫色标出属于当前 SSH 登录用户的 GPU 进程。
- 左键点击菜单栏图标可以打开或收起面板。
- 右键点击菜单栏图标可以调整刷新频率、设置开机启动或退出应用。
- 只有面板打开时才会轮询；收起面板后会暂停 SSH 查询。

## 安装

1. 从 [最新 Release](https://github.com/junle-chen/monitor/releases/latest)
   下载 `GPU-Pulse-macOS.zip`。
2. 解压并把 `GPU Pulse.app` 移动到 `/Applications`。
3. 如果 macOS 首次启动时拦截本地签名版本，请按住 Control 点击应用并选择
   **打开**。
4. 创建本机服务器配置：

   ```zsh
   mkdir -p "$HOME/Library/Application Support/GPU Pulse"
   cp app/servers.example.json \
     "$HOME/Library/Application Support/GPU Pulse/servers.json"
   ```

5. 在本机编辑 `servers.json`，填入自己的显示名称和 SSH 别名，然后确认每个
   别名都能免交互密码运行：

   ```zsh
   ssh gpu-server-1 nvidia-smi
   ```

不要提交真实的 `servers.json`。GPU Pulse 需要 macOS 13 或更高版本；远程
服务器需要提供 `nvidia-smi` 和基于密钥的 SSH 登录。

## 使用方法

- **打开/收起：** 左键点击菜单栏中的柱状图图标。
- **立即刷新：** 点击面板右上角的圆形刷新按钮。
- **设置：** 右键点击菜单栏图标。
- **刷新频率：** 可选择 5、10、30 或 60 秒，默认是 10 秒。
- **开机启动：** 在右键菜单中开启；macOS 可能要求在
  **系统设置 → 通用 → 登录项** 中批准。
- **退出：** 在右键菜单中选择 **Quit GPU Pulse**。

SSH 连接最多复用 60 秒，避免反复执行跳板机和认证握手。空闲超过该时间后，
再次打开面板仍可能重新建立连接。

## 从源码构建

```zsh
cd app
swift build -c release
```

运行时服务器配置来自
`~/Library/Application Support/GPU Pulse/servers.json`。仓库中的
[`app/servers.example.json`](app/servers.example.json) 只包含占位别名。

## 仓库结构

| 路径 | 说明 |
| --- | --- |
| [`app/`](app/) | 当前原生 SwiftUI macOS 应用 |
| [`web/`](web/) | 以前的 Streamlit Web 版本 |
| [`assets/`](assets/) | 应用图标和经过隐私处理的 README 截图 |

## 以前的 Web 版本

原始 Streamlit 监控程序保留在 [`web/`](web/)：

```zsh
cd web
pip install pandas streamlit
streamlit run monitor.py
```

该版本仅作为历史参考保留，不再是主要版本。
