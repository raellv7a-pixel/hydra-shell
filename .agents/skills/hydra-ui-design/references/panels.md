# Panels & Framed Architecture Reference

This reference documents the spatial and architectural mechanics of Hydra Shell panels, the Framed bar system, background rendering, and panel lifecycles.

---

## 1. Tripartite Architectural Model

To avoid confusion between current code and design intent, agents must always distinguish these three layers:

```
┌────────────────────────────────────────────────────────┐
│ 1. CURRENT RUNTIME BASELINE                            │
│    • PanelService enforces 1 active normal panel       │
│    • Slot 0 (open), Slot 1 (closing), Slot 2 (modal)   │
│    • Imperative panel switching                        │
└────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. BINDING DESIGN CONTRACT (Required Today)            │
│    • All panels MUST dock into the frame               │
│    • Assign canonical region (Top/Bottom Center, etc.) │
│    • Define collision strategy (Replace/Shrink/etc.)   │
│    • Zero arbitrary floating center popups             │
└────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 3. FUTURE SPATIAL INFRASTRUCTURE                       │
│    • Automated multi-panel layout manager              │
│    • Dynamic neighbor margin negotiation               │
│    • Multi-panel coexistence and collision engine      │
└────────────────────────────────────────────────────────┘
```

---

## 2. SmartPanel Architecture (`Modules/MainScreen/SmartPanel.qml`)

`SmartPanel` is the base container component for all main shell panels hosted within `MainScreen`:

### Key Properties & Contracts
- `panelContent`: Component defining the panel's interior UI.
- `panelID`: Unique identifier string for binding panels to widgets.
- `preferredWidth`, `preferredHeight`: Natural dimensions of the panel.
- `preferredWidthRatio`, `preferredHeightRatio`: Proportional screen sizing.
- `panelBackgroundColor`: Defaults to `Color.mSurfaceContainer` (or `Color.mSurfaceContainerHigh` when `modalOverlay` is true).
- `allowAttach`: Boolean indicating whether the panel attaches to the frame edge.
- `forceAttachToBar`: Enforces docking regardless of default orientation.
- `attachmentOverlap`: Hardcoded to `1px` to eliminate hairline rendering gaps caused by fractional display scaling.
- `modalOverlay`: When `true`, panel layers over the current normal panel without closing it, and background clicks do not dismiss it (e.g. Polkit prompt).
- `exclusiveKeyboard`: Configures Wlr keyboard grab (`WlrKeyboardFocus.Exclusive` vs `WlrKeyboardFocus.OnDemand`).
- `presented`: Single boolean flag driving open and close transitions simultaneously (`isPanelVisible && !isClosing`).

### Subpixel Attachment Mechanics
When a panel docks to an edge or bar, it expands slightly into the bar area by `attachmentOverlap` (1 pixel):
```qml
// Pre-computed overlap to prevent subpixel hairline seams
var topBarEdgeWithOverlap = root.barHeight - root.attachmentOverlap;
```
This guarantees that antialiasing or fractional scaling never exposes desktop wallpaper between the frame and the panel.

---

## 3. Dynamic Background Rendering (`AllBackgrounds.qml` & `PanelBackground.qml`)

Hydra does not render panel backgrounds directly inside each panel item. Instead, it uses a **single unified GPU-accelerated Shape container** in `Modules/MainScreen/Backgrounds/`:

### The 3-Slot Background System
`AllBackgrounds.qml` allocates three `PanelBackground` ShapePaths:
- **Slot 0:** The currently open or opening panel (`PanelService.backgroundSlotAssignments[0]`).
- **Slot 1:** The closing panel during animated transition (`PanelService.backgroundSlotAssignments[1]`).
- **Slot 2:** The modal overlay panel (`PanelService.backgroundSlotAssignments[2]`), rendered directly atop Slot 0.

### 4-State Corner Curvature Engine
To achieve seamless visual integration between panels and the screen frame, `PanelBackground.qml` and `ShapeCornerHelper` calculate a per-corner state:
- **State -1:** Flat / square corner (radius = 0). Used on edges contacting the frame or screen boundary.
- **State 0:** Normal inner rounded corner (radius = `Style.radiusL`).
- **State 1:** Horizontal inversion (outer curve on X-axis) for organic corner transitions.
- **State 2:** Vertical inversion (outer curve on Y-axis).

---

## 4. Framed Spatial System (`BarBackground.qml`)

When `Settings.data.bar.barType === "framed"`, the bar and screen frame are treated as a single continuous surface:
- **Frame Thickness:** `Settings.data.bar.frameThickness` (default `12px`).
- **Frame Corner Radius:** `Settings.data.bar.frameRadius` (default `20px`).
- **Screen Cutout (Hole):** `BarBackground.qml` cuts an inner rectangular viewport with rounded corners for desktop windows, while reserving the outer perimeter for the shell frame, edge shelf, and docked panels.

---

## 5. Panel Lifecycle & Service (`Services/UI/PanelService.qml`)

`PanelService` coordinates panel visibility and interaction across displays:

### State Variables
- `openedPanel`: The single normal active panel instance.
- `closingPanel`: The panel currently executing its exit animation.
- `modalPanel`: The active modal overlay (Polkit), tracked independently.
- `activePanel`: Readonly alias resolving to `modalPanel || openedPanel`.

### Core Methods
- `registerPanel(panel)`: Registers panel instance by `objectName`.
- `openPanel(panelID, screen)`: Initiates panel opening; closes existing normal panel via transition.
- `closePanel(screen)`: Initiates exit animation for the open panel.
- `assignToSlot(slotIndex, panel)`: Updates background shape slots in `AllBackgrounds`.
- `findScreenForPanels()`: Resolves the appropriate screen based on cursor focus and monitor configuration.

---

## 6. Canonical Docking Regions

All shell panels must map to one of Hydra's standard regions:

| Region | Primary Panel | Docking Behavior |
| :--- | :--- | :--- |
| **Top Center** | Dashboard (Control Center) | Attached to top frame edge; expands downward |
| **Bottom Center** | Application Launcher | Attached to bottom frame edge; expands upward |
| **Center Right** | Session Menu | Attached to right frame edge; vertically centered |
| **Center Left** | Portal / Share Picker | Attached to left frame edge; vertically centered |
| **Bottom Left** | Window Switcher (Alt-Tab) | Grounded to bottom-left frame corner |
| **Widget Anchor** | System Tray & Widget Popouts | Dynamically follows trigger widget (`useButtonPosition = true`) |
| **Modal Overlay** | Polkit Prompts | Centered modal stack over active panel; non-dismissable |
| *Top Left / Top Right / Bottom Right* | *Unassigned* | Reserved for future capabilities |

---

## 7. Collision & Coexistence Strategies

When designing future multi-panel interactions, use these 4 defined strategies:

1. **REPLACE:** Standard for independent workflows. Panel B closes Panel A and occupies the region.
2. **SHRINK:** Opposing panels (e.g. Dashboard at top and Launcher at bottom) reduce max height to preserve a minimum visibility gap.
3. **SHIFT:** Adjacent panels translate horizontally or vertically to avoid overlap.
4. **OVERLAY:** Genuinely modal interactions (Polkit) that require the underlying caller to remain visible.

*(Do not implement custom collision managers in features today; adhere to the single-panel baseline in `PanelService` while designing geometries for future compatibility).*
