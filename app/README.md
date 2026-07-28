# GPU Pulse

A native macOS menu-bar monitor for GPU servers reached through locally
configured SSH aliases.

## Behavior

- Refreshes all four hosts concurrently at a selectable 5/10/30/60-second
  interval (10 seconds by default) while the popover is open.
- Reuses one multiplexed SSH connection per host (`ControlPersist=60`) instead of performing a full handshake every 10 seconds.
- Reads only `nvidia-smi` over the SSH aliases already configured on the Mac.
- Shows four glass server cards in a 2×2 layout, each listing GPU #0 through GPU #7.
- Each GPU uses one horizontal bar: length represents VRAM usage and color represents utilization.
- Bar color represents utilization: green below 50%, yellow from 50–79%, and red at 80% or above. No usage numbers are printed; each card labels the bar column as `MEM`.
- A single compact `UTIL` green-to-yellow-to-red gradient legend appears above the card grid.
- Left-click the menu-bar item to open the popover.
- Click the menu-bar item to show or hide the monitor.
- Use the refresh button beside the UTIL legend to fetch the latest GPU data immediately.
- GPUs used by the current SSH login user are marked with a slim indigo rail, bold GPU label, and a faint indigo row background; the compact legend reads `MINE`.
- GPU data refreshes every 10 seconds only while the popover is open. Closing it pauses polling; reopening refreshes immediately.
- Right-click the menu-bar icon to quit, toggle Launch at Login, or choose a 5/10/30/60-second refresh interval.

## Build

```zsh
swift build -c release
```

The app reads `~/.ssh/config` and automatically selects the four exact `Host`
names beginning with `zxcpu1` through `zxcpu4`. The UI displays only
`ZXCPU1–4`; full host names are never embedded in the app.

The packaged `.app` in the deliverables is ad-hoc signed for local use.
