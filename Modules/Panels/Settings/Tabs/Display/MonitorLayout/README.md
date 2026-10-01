# Monitor Layout

Monitor Layout is a Hydra Shell plugin and settings module for visually arranging multiple monitors and managing their display modes, scaling, and orientation, with native support for Hyprland and Sway compositors.

## Key Features

- **Magnetic Snapping & Flush Attachment**: Dragging monitors snaps to adjacent edges when their bounds overlap; far drops attach to the nearest edge so every active display stays connected.
- **Frozen Canvas Dragging**: Canvas bounds, size, scale, and offsets stay fixed during a drag. Drop coordinates use that frozen transform, then normalize once on release.
- **Explicit Primary Display**: Designate an active output as primary. The layout rebases it to `(0, 0)` while preserving every output's relative offsets.
- **Resolution-Aware Discrete Scale Ladder**: Hyprland scale choices are bounded by resolution and limited to decimal factors that yield integral logical-pixel dimensions. Scale is coerced to the nearest valid step after resolution or orientation changes; Sway retains its existing slider.
- **Strict Hyprland Mode Fidelity**: Resolution choices come only from Hyprland's advertised `availableModes`, including their actual refresh rates. Unadvertised modes are never synthesized.
- **Transactional Apply & Verification**:
  - Before apply, the compositor state is fetched again. If it changed outside this panel, the draft is discarded and the current layout is reloaded.
  - Hyprland readback verifies output identity, mode, refresh, scale, transform, and position. Sway retains its previous active-output-count check.
  - A 15-second confirmation countdown ("Keep" / "Revert") prevents an unconfirmed layout from being retained.
  - Apply failures, mismatched readback, timeout, and manual cancellation trigger rollback; rollback readback is verified before success is reported.
  - If rollback fails or cannot be verified, the snapshot stays in memory for retry.
- **Dual Config Persistence**:
  - Saves verified, confirmed layouts to `~/.config/hypr/hydra-shell/monitors.lua` (Hyprland 0.55+ Lua syntax).
  - Generates legacy `hyprland.conf` snippets ready for clipboard export.
  - Unconfirmed draft layouts are never persisted to disk.

## VRR Note (Variable Refresh Rate)

Live Hyprland (0.56.2+) exposes an effective boolean (`vrr: true|false`) in `hyprctl monitors -j`, whereas monitor configuration rules support policies `0` (off), `1` (on), `2` (fullscreen only), and `3`. Because the exact user policy cannot be losslessly round-tripped from compositor output, a per-monitor VRR toggle is intentionally omitted from this panel to avoid overwriting or corrupting advanced VRR rules.

## Usage

1. Open **Settings** → **Monitores** (or the Monitor Layout widget).
2. Drag monitor tiles on the canvas to rearrange them visually. Snapping and flush alignment engage automatically.
3. Select any monitor to inspect its properties:
   - Toggle output activation or mirroring.
   - Click **Definir como Monitor Principal** to set origin `(0, 0)`.
   - Select supported resolutions, refresh rates, discrete scale factors, or rotation.
4. Click **Aplicar Agora** to preview live. A 15-second confirmation dialog will appear.
5. Click **Manter** to confirm, or **Reverter** to restore the previous layout.
6. Click **Salvar no Hyprland** to write the confirmed configuration permanently.
