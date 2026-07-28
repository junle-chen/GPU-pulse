# GPU Pulse

[English](README.md) | [简体中文](README.zh-CN.md)

<p align="center">
  <img src="assets/gpu-pulse-icon.png" width="112" alt="GPU Pulse 图标">
</p>

GPU Pulse 是一款简洁的原生 macOS 菜单栏应用，用于查看多台服务器的 GPU
显存占用和利用率。应用直接使用你已有的 SSH 配置连接服务器，不依赖托管后端，
也不会把监控数据上传到其他服务。

## 监控面板

![显示四台通用服务器的 GPU Pulse 面板](assets/gpu-pulse-dashboard.png)

截图出于隐私考虑使用 `SERVER 1–4` 这类通用名称。应用运行时会列出
`~/.ssh/config` 中明确配置的 `Host`，供用户选择需要监控的服务器。面板名称
取第一个点号前的部分，例如 `zxcpu1.cse.example.edu` 显示为 `ZXCPU1`。

## GPU 进程详情

![GPU Pulse 服务器详情中的隐私安全 GPU 进程示例](assets/gpu-pulse-detail.png)

点击服务器卡片右上角、`MEM` 旁边的蓝紫色**三横线按钮**，即可打开该服务器
最近一次刷新的进程详情；这个操作不会额外建立 SSH 连接。

- **GPU** 是设备编号（`#0` 到 `#7`）。同一张 GPU 有多个进程时，编号只在
  第一行显示一次，其余进程放在同一个淡色区块中。
- **USER** 是远程系统中拥有该进程的用户；蓝紫色短竖线表示当前 SSH 登录用户。
- **PROCESS** 是远程进程表报告的可执行程序。
- **TIME** 是进程已经运行的时长，不是启动时间点。
- **MEM** 是该进程使用的 GPU 显存。数字的绿色、黄色或红色跟随所属 GPU 的
  当前利用率颜色，并不是根据这条进程的显存数值判断。

界面刻意不显示 PID。截图中的服务器、用户名和进程均为通用演示数据。

## 面板信息

- 四台服务器以紧凑的 2×2 网格显示。
- 四台以内不显示滚动条；更多服务器会继续以双列排列，并使用紧凑的滚动条在
  面板内纵向滚动。
- 每一行代表一张 GPU：进度条长度表示显存占用，绿色、黄色和红色表示 GPU
  利用率。
- `MINE` 用蓝紫色标出属于当前 SSH 登录用户的 GPU 进程。
- 每张服务器卡片右上角有一个蓝紫色三横线详情按钮，用紧凑的 nvitop 风格表格
  汇总该服务器全部 GPU。
- 同一张 GPU 的多个进程共用一个紧凑淡色区块，GPU 编号只在第一行显示一次；
  固定宽度的 `TIME` 和 `MEM` 列在滚动时仍保持对齐。
- 每条进程的 `MEM` 数字会使用对应 GPU 利用率的绿色、黄色或红色。
- 详情面板会随内容自动增高，常见的八张 GPU 可一次显示；只有进程过多、可能超出
  屏幕安全高度时才启用滚动。
- 左键点击菜单栏图标可以打开或收起面板。
- 右键点击菜单栏图标可以调整刷新频率、设置开机启动或退出应用。
- 只有在 **Servers…** 中勾选的 SSH Host 才会建立连接。
- 首次启动会自动打开 **Servers** 窗口，并且在用户选择前不会连接任何 SSH
  Host。
- 只有面板打开时才会轮询；收起面板后会暂停 SSH 查询。
- 点击桌面或其他 App 时，监控面板会自动收起。

## 安装

1. 从 [最新 Release](https://github.com/junle-chen/GPU-pulse/releases/latest)
   下载 `GPU-Pulse-macOS.zip`。
2. 解压并把 `GPU Pulse.app` 移动到 `/Applications`。
3. 如果 macOS 首次启动时拦截本地签名版本，请按住 Control 点击应用并选择
   **打开**。
4. 首次启动会自动打开 **Servers** 窗口，在其中勾选需要监控的 SSH Host；
   之后可以通过菜单栏图标的右键菜单再次打开。

GPU Pulse 会读取本机现有 `~/.ssh/config` 中明确配置的 SSH 别名，不需要单独
的应用配置文件。应用需要 macOS 13 或更高版本；远程服务器需要提供
`nvidia-smi` 和基于密钥的 SSH 登录。

## 使用方法

- **打开/收起：** 左键点击菜单栏中的柱状图图标。
- **立即刷新：** 点击面板右上角的圆形刷新按钮。
- **GPU 进程详情：** 点击服务器卡片右上角、`MEM` 旁边的蓝紫色三横线按钮。
- **选择服务器：** 右键点击菜单栏图标并选择 **Servers…**，可勾选任意数量；
  选择结果只保存在本机。
- **刷新频率：** 可选择 5、10、30 或 60 秒，默认是 10 秒。
- **开机启动：** 在右键菜单中开启；macOS 可能要求在
  **系统设置 → 通用 → 登录项** 中批准。
- **退出：** 在右键菜单中选择 **Quit GPU Pulse**。

## 右键菜单

![GPU Pulse 菜单栏右键菜单](assets/gpu-pulse-context-menu.png)

右键点击菜单栏中的 GPU Pulse 图标，无需打开监控面板即可使用以下控制：

- **Servers…：** 打开 SSH Host 选择窗口。
- **Launch at Login：** 登录 macOS 后自动启动 GPU Pulse。
- **Refresh Interval：** 选择 5、10、30 或 60 秒的监控刷新间隔。
- **Quit GPU Pulse：** 停止监控并退出应用。

SSH 连接最多复用 60 秒，避免反复执行跳板机和认证握手。空闲超过该时间后，
再次打开面板仍可能重新建立连接。

## 从源码构建

```zsh
cd app
swift build -c release
```

应用从本机 `~/.ssh/config` 中明确配置的 `Host` 里选择监控服务器；通配符
配置会被忽略，完整主机名不会写入应用。

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
