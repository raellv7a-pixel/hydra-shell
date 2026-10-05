# Motion & Animation Invariants in Hydra Shell

This reference documents Hydra's animation durations, easing curves, spatial continuity principles, and accessibility/performance gating.

---

## 1. Motion Philosophy

In Hydra Shell, motion is functional rather than decorative:
- **Spatial Origin:** Motion communicates where an element came from and where it returns. Docked panels emerge from and recede into their originating frame edges.
- **State Explanation:** Transitions explain state changes (e.g., expanding cards, switching toggle states, opening submenus).
- **Zero Gratuitous Animation:** Never animate purely for visual spectacle. Animations must be snappy and purposeful.

---

## 2. Duration Tokens (`Commons/Style.qml`)

All durations in Hydra are centralized in `Style` and scale dynamically:

| Token | Base Duration | Purpose |
| :--- | :--- | :--- |
| `Style.animationFaster` | 75ms | Micro-interactions, tiny icon state flips, badge updates |
| `Style.animationFast` | 150ms | Toggle switches, collapsible expansions, button clicks |
| `Style.animationNormal` | 300ms | Standard panel open/close, view transitions |
| `Style.animationSlow` | 450ms | Major screen layout reorganizations |
| `Style.animationSlowest`| 750ms | Palette color shifts and dynamic wallpaper theme transitions |
| `Style.hoverEnterDuration` | 100ms | Pointer hover entry |
| `Style.hoverLeaveDuration` | 30ms | Pointer hover exit |

### Delays
- `Style.tooltipDelay`: 300ms (standard hover tooltip reveal)
- `Style.tooltipDelayLong`: 1200ms (extended tooltip reveal for dense widgets)
- `Style.pillDelay`: 500ms (pill notification reveal)

---

## 3. Scaling & Performance Gating

All duration tokens in Hydra embed automatic gating:

```qml
// Example formula from Commons/Style.qml
readonly property int animationFast: (Settings.data.general.animationDisabled || PowerProfileService.hydraPerformanceMode) ? 0 : Math.round(150 / Settings.data.general.animationSpeed)
```

### Invariants
1. **Performance Mode:** When `PowerProfileService.hydraPerformanceMode` is enabled, all animation durations evaluate to `0ms` (instant cuts).
2. **Reduced Motion:** When `Settings.data.general.animationDisabled` is `true`, all durations collapse to `0ms`.
3. **Speed Ratio:** All non-zero durations scale inversely with `Settings.data.general.animationSpeed`.

---

## 4. Asymmetric Hover Timing Invariant

Hydra enforces an asymmetric timing curve for hover and highlight transitions across all interactive controls:

```
Pointer Enter ───[ 100ms: Smooth fade-in ]───► Hover State
                                                 │
Pointer Leave ◄──[  30ms: Rapid fade-out ]───────┘
```

- **Enter Duration (`Style.hoverEnterDuration` = 100ms):** Smooth, welcoming transition.
- **Leave Duration (`Style.hoverLeaveDuration` = 30ms):** Extremely rapid snap-back.
- **UX Rationale:** When a user moves their mouse quickly across a list of items or the bar, symmetric fade-out leaves visual trails ("ghost highlights"). The rapid 30ms exit ensures the active highlight stays strictly under the pointer without trailing.

---

## 5. Easing Curve Conventions

Hydra standardizes on three specific easing curves across panels and controls:

### 1. Panel & Surface Transitions (`OutCubic` / `InCubic`)
- **Opening / Appearing:** `Easing.OutCubic` (fast deceleration into view).
- **Closing / Disappearing:** `Easing.InCubic` (smooth acceleration offscreen).
- **Usage:** Panel expand/collapse, `SmartPanel` open/close, sheet slides.

### 2. Tactile Press Feedback (`Easing.OutBack`)
- **Press / Settle:** `Easing.OutBack`
- **Usage:** Interactive button press release, toggle switch flips, pill snaps.
- **Rule:** Uses a modest, controlled overshoot; NEVER use aggressive bouncy physics (`OutBounce` or `OutElastic`).

### 3. Passive State Changes (`Easing.InOutQuad` / `Easing.OutQuad`)
- **Color Transitions & Fades:** `Easing.InOutQuad` or `Easing.OutQuad`
- **Usage:** Background color interpolations, theme changes, opacity fades.

---

## 6. Directional Spatial Continuity

Panels must open in the direction corresponding to their frame attachment:

- **Top Center (Dashboard):** Rolls downward from the top frame edge.
- **Bottom Center (Launcher):** Rolls upward from the bottom frame edge.
- **Center Right (Session Menu):** Rolls inward from the right frame edge.
- **Center Left (Portal):** Rolls inward from the left frame edge.
- **Detached Popups:** Roll downward from top.

### Reconciliation with Generic Qt Guidance
Generic Qt guidance (`qt-ui-design`) warns: *"Animate only transform and opacity in QML; animating geometry triggers layout recalculation"*.

**Hydra's Architectural Model:**
In Hydra Shell, panels deliberately animate geometric bounds (`width` and `height`) during open/close so the unified GPU-accelerated background in `AllBackgrounds.qml` (`layer.enabled: true`, `preferredRendererType: Shape.CurveRenderer`) draws the exact contour cutout in real time. Because geometry animations are handled cleanly through `SmartPanel`'s unified `presented` driver and gated to `0ms` in performance mode, this pattern is approved and canonical in Hydra.
