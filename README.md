# GPU Pulse

[English](README.md) | [简体中文](README.zh-CN.md)

<p align="center">
  <img src="assets/gpu-pulse-icon.png" width="112" alt="GPU Pulse icon">
</p>

GPU Pulse is a compact native macOS menu-bar app for checking GPU memory and
utilization across multiple servers. It talks directly to the servers over your
existing SSH configuration—there is no hosted backend and no monitoring data is
uploaded elsewhere.

## Dashboard

![GPU Pulse dashboard showing four generic servers](assets/gpu-pulse-dashboard.png)

The screenshot uses generic `SERVER 1–4` labels for privacy. At runtime, the app
lists the explicit `Host` entries from `~/.ssh/config` and lets you choose the
servers to monitor. Dashboard labels use the part before the first dot, so
`zxcpu1.cse.example.edu` appears as `ZXCPU1`.

## What It Shows

- Four servers are shown in a compact 2×2 grid.
- Additional servers continue in the same two-column grid with vertical
  scrolling.
- Each row represents one GPU. Bar length is memory usage; green, yellow, and
  red represent GPU utilization.
- `MINE` highlights GPUs running processes owned by your SSH login user.
- Left-click the menu-bar icon to open the monitor.
- Right-click it to change the refresh interval, toggle Launch at Login, or
  quit GPU Pulse.
- Only SSH hosts selected in **Servers…** are contacted.
- Polling runs only while the panel is open. Closing the panel pauses SSH
  queries.

## Install

1. Download `GPU-Pulse-macOS.zip` from the
   [latest release](https://github.com/junle-chen/GPU-pulse/releases/latest).
2. Unzip it and move `GPU Pulse.app` into `/Applications`.
3. Control-click the app and choose **Open** on the first launch if macOS asks
   you to confirm the locally signed build.
4. Right-click the menu-bar icon, choose **Servers…**, and select the SSH hosts
   to monitor.

GPU Pulse reads explicit SSH aliases from your existing `~/.ssh/config`; no
separate app configuration file is needed. It requires macOS 13 or newer.
Remote hosts must provide `nvidia-smi` and key-based SSH access.

## Usage

- **Open/close:** left-click the menu-bar chart icon.
- **Refresh now:** click the circular arrow in the upper-right corner.
- **Servers:** right-click the menu-bar icon, choose **Servers…**, then select
  any number of hosts. The selection is stored only on this Mac.
- **Refresh frequency:** choose 5, 10, 30, or 60 seconds. The default is 10
  seconds.
- **Launch at login:** enable it from the right-click menu. macOS may ask you to
  approve it in **System Settings → General → Login Items**.
- **Quit:** choose **Quit GPU Pulse** from the right-click menu.

SSH connections are multiplexed for up to 60 seconds to avoid repeating jump
host and authentication handshakes. A reconnect may still occur after that
idle window expires.

## Build from Source

```zsh
cd app
swift build -c release
```

The monitored hosts are selected from the explicit `Host` entries in your local
`~/.ssh/config`; wildcard entries are ignored and full host names are not
embedded in the app.

## Repository Layout

| Path | Description |
| --- | --- |
| [`app/`](app/) | Current native SwiftUI macOS application |
| [`web/`](web/) | Previous Streamlit web version |
| [`assets/`](assets/) | App icon and privacy-safe README screenshots |

## Previous Web Version

The original Streamlit monitor remains available in [`web/`](web/):

```zsh
cd web
pip install pandas streamlit
streamlit run monitor.py
```

It is retained for reference and is no longer the primary version.
