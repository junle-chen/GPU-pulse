# GPU Pulse

A native macOS menu-bar monitor for GPU servers reached through locally
configured SSH aliases.

## Behavior

- Refreshes all selected hosts concurrently at a selectable 5/10/30/60-second
  interval (10 seconds by default) while the popover is open.
- Reuses one multiplexed SSH connection per host (`ControlPersist=60`) instead of performing a full handshake every 10 seconds.
- Reads only `nvidia-smi` over the SSH aliases already configured on the Mac.
- Shows glass server cards in a two-column layout, each listing GPU #0 through GPU #7. Scrolling and a compact scrollbar appear only when more than four servers are selected.
- Each GPU uses one horizontal bar: length represents VRAM usage and color represents utilization.
- Bar color represents utilization: green below 50%, yellow from 50–79%, and red at 80% or above. No usage numbers are printed; each card labels the bar column as `MEM`.
- A single compact `UTIL` green-to-yellow-to-red gradient legend appears above the card grid.
- Left-click the menu-bar item to open the popover.
- Click the menu-bar item to show or hide the monitor.
- Use the refresh button beside the UTIL legend to fetch the latest GPU data immediately.
- GPUs used by the current SSH login user are marked with a slim indigo rail, bold GPU label, and a faint indigo row background; the compact legend reads `MINE`.
- GPU data refreshes every 10 seconds only while the popover is open. Closing it pauses polling; reopening refreshes immediately.
- Right-click the menu-bar icon to quit, toggle Launch at Login, or choose a 5/10/30/60-second refresh interval.
- The **Servers…** settings window lists explicit `Host` entries from
  `~/.ssh/config` and allows any number of selections. Only selected hosts are
  contacted.
- On first launch, the Servers window opens automatically. Completing one
  selection dismisses future onboarding; intentionally clearing all selections
  later does not reopen it on every launch.
- Dashboard labels use the text before the first dot in each SSH alias; the
  actual SSH command continues to use the complete alias.

## Build

```zsh
swift build -c release
```

The app reads explicit `Host` entries from `~/.ssh/config`. Wildcard entries are
ignored, and the selected aliases are stored locally in `UserDefaults`.

The packaged `.app` in the deliverables is ad-hoc signed for local use.
