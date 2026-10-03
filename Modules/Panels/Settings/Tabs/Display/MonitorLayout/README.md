# Monitor Layout

Native Umbriel monitor controls used by **Settings → Tela → Arranjo de Monitores**.
`Services/Hardware/MonitorService.qml` owns the existing draft/apply/verify/confirm/rollback state machine; `backends/UmbrielBackend.js` adapts native output snapshots and builds writer commands.

## Geometry and modes

- `umbriel outputs --json` supplies identity, current/advertised modes, refresh, enabled state, position, scale and transform.
- Fractional scales are preserved without coercion or invented mode/scale. Tile dimensions come from the rotated physical mode divided by output scale; all tiles share one viewport scale.
- The canvas owns pointer gestures outside the monitor delegates. Press captures logical origin, pointer origin, scale, offsets, bounds and viewport/canvas size; drag previews logical deltas without mutating the draft or recalculating zoom. Release snaps and commits the draft before fitting again; cancel leaves the draft unchanged.
- Auto-fit uses enabled outputs, 20 UI-pixel padding and the existing 72% fit fraction. Its scale is limited to `0.02–0.25 × uiScaleRatio` (a 1920-wide tile is at most 480 UI pixels), with scrolling for layouts that exceed the minimum-scale viewport.
- Selection uses stable native output names, independently of session focus and layout origin. The selected tile is raised; repeated clicks in overlapping areas cycle the outputs, including complete overlap.
- “Primary” in this editor means the logical layout origin, not an Umbriel focused-output flag. Choosing it rebases the layout to `(0, 0)` while preserving relative offsets; it never disables tile selection or dragging.
- Adaptive-sync policy remains user-owned and is not changed by this panel.

## Apply and persistence

1. Fetch native state before applying. External changes invalidate the old draft.
2. Generate `$XDG_CONFIG_HOME/umbriel/hydra/outputs.toml` through `Scripts/python/umbriel_config.py`.
3. Validate a complete staged configuration, atomically replace owned files, then `umbriel msg config-reload`.
4. Verify identity, mode, refresh, scale, transform and position through a new query.
5. Keep the layout or revert within the existing 15-second countdown. Revert writes and validates the previous snapshot; failed rollback retains the snapshot for retry.

Because Umbriel applies output settings through configuration, preview uses the owned output fragment too; it remains provisional until Keep or rollback. The Save action writes confirmed outputs, not the edited draft. The clipboard action exports native TOML. Personal options and includes are preserved; optional Hydra includes are not duplicated.

Queries run on initialization, user refresh and transaction boundaries, not continuous polling.

## Verification

```bash
node --test Modules/Panels/Settings/Tabs/Display/MonitorLayout/MonitorGeometry.test.mjs
python3 -m unittest discover -s Scripts/python/tests -p 'test_umbriel*.py' -v
```

Configuration tests use temporary HOME/XDG roots. Actual layout smoke uses isolated headless Umbriel, never the active desktop.
