# Monitor Layout

Native Umbriel monitor controls used by **Settings → Tela → Arranjo de Monitores**.
`Services/Hardware/MonitorService.qml` owns the existing draft/apply/verify/confirm/rollback state machine; `backends/UmbrielBackend.js` adapts native output snapshots and builds writer commands.

## Geometry and modes

- `umbriel outputs --json` supplies identity, current/advertised modes, refresh, enabled state, position, scale and transform.
- Fractional scales are preserved; there is no Hyprland scale coercion or invented mode/scale.
- Dragging freezes the canvas transform until drop. Snapping, flush attachment and gap cleanup use logical monitor rectangles.
- Selecting a primary display rebases it to `(0, 0)` while preserving relative offsets.
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
