# Hydra UI/UX Design Guidelines

Durable design and interaction guidelines for Hydra Shell. All user-visible surfaces, settings, panels, OSDs, and controls must adhere to these principles.

---

## 1. Visual Identity & Design Foundation

- **Primary Foundation:** Material You / Material 3 adapted to Hydra's distinctive visual identity.
- **Composition & Surface References:**
  - Modern Android / Pixel UI serves as the primary reference for surface grouping, tonal elevation, and natural interaction rhythms.
  - Modern Apple / macOS / iOS serves as a secondary reference for breathing room, optical clarity, hierarchy, progressive disclosure, and quiet polish.
- **Relationship with Other Shells:**
  - **Noctalia V4:** Historical functional reference only. **NEVER** treat Noctalia V4 as a visual or styling reference.
  - **Noctalia V5:** Behavioral, architectural, and structural reference when useful. **NEVER** clone Noctalia V5 aesthetically. Hydra is not recolored Noctalia.
  - **Caelestia:** Structural reference strictly for spatial orchestration, edge docking concepts, and panel coexistence models. **NEVER** adopt Caelestia's aesthetic (no metaballs, organic blob shaders, or gooey fusion styling).
---

## 2. Structural Hierarchy & The Golden Rules

Every UI decision must follow these structural invariants:

> **Color creates grouping.**<br>
> **Spacing creates separation.**<br>
> **Typography creates hierarchy.**<br>
> **Shape creates identity.**<br>
> **Motion creates continuity.**<br>
> **Borders are semantic, not structural decoration.**

- Delimit cards and functional clusters through semantic Material surfaces, rounded shapes, and proportional padding.
- Permanent structural outlines create visual clutter ("boxes inside boxes"). Reserve borders strictly for active focus, interactive selection, drag states, or semantic error highlights.
- **Settings Sidebar Surface:** Keep one inset `mSurfaceContainerHigh` surface with `Style.radiusL`, token spacing, and a quiet `NDropShadow` on the background only. The navigation surface remains opaque and legible independently of window translucency or compositor blur; no decorative outline or per-section cards.
- **Settings Navigation Groups:** General, Personalization, Shell Interface, Session and Security, Devices and System, Integrations, Advanced, and About are secondary translated headings. All pages stay directly accessible; sections do not collapse. Preserve the existing whole-sidebar compact toggle and selected-item capsule.
- **Settings Navigation Model:** Store section keys on the existing `tabsModel`; keep page IDs stable and resolve search destinations by their page label key, not their presentation index. Regenerate `Assets/settings-search-index.json` when the page order changes.
- **Settings Sidebar Scrolling:** Hide the scrollbar in navigation and search results without disabling scrolling. Cache the small destination list to keep section measurements stable, and keep programmatic page selection in view. The main content scrollbar is unaffected.
- **Settings Composition:** Adapt iNiR's iRiS organization, not its theme or controls: user identity beneath search, category marks in the sidebar and page title, and compact disclosure headings on quiet tonal cards. General starts with a responsive wallpaper/profile overview and links to Hydra's existing wallpaper and color pages. The wallpaper preview is omitted at narrow widths; all controls and page IDs remain available.
- **Category Artwork:** `Widgets/NColorIcon.qml` uses the bundled filled Material Symbols Rounded font and the iRiS identity hues centralized in `Commons/ColoredIcons.qml`. These colors and the restrained plate gradient belong to icon artwork only, not selection, state, surfaces, or control styling. `NIcon` remains the monochrome control/action icon. Font provenance and license are in `Assets/Fonts/material-symbols/ATTRIBUTION.txt`.
- **Reusable Category Keys:** Settings keys and `folder-tools`, `folder-productivity`, `folder-creativity`, `folder-games`, `folder-development`, `folder-multimedia`, `folder-internet`, `folder-system`, `folder-education`, and `folder-utilities` are available through `NColorIcon { icon: "..."; size: ... }`. Unmapped keys retain their actual Tabler artwork on the tile. This does not change the launcher.

---

## 3. Semantic Surfaces & Color Tokens

All UI colors must derive strictly from Hydra's design tokens in `Commons/HydraColor.qml` and `Commons/Style.qml`:

- **Surfaces & Containers:**
  - `HydraColor.mSurface`, `HydraColor.mSurfaceVariant`, `HydraColor.mSurfaceContainerLowest`, `HydraColor.mSurfaceContainerLow`, `HydraColor.mSurfaceContainer`, `HydraColor.mSurfaceContainerHigh`, `HydraColor.mSurfaceContainerHighest`
- **Tonal Brand Accents:**
  - `HydraColor.mPrimary`, `HydraColor.mOnPrimary`, `HydraColor.mPrimaryContainer`, `HydraColor.mOnPrimaryContainer`
  - `HydraColor.mSecondary`, `HydraColor.mSecondaryContainer`, `HydraColor.mTertiary`, `HydraColor.mTertiaryContainer`
- **Text & Icon Roles:**
  - `HydraColor.mOnSurface` (high emphasis: titles, active text)
  - `HydraColor.mOnSurfaceVariant` (medium emphasis: descriptions, labels, hints)
  - `HydraColor.mOutline`, `HydraColor.mOutlineVariant` (semantic borders, subtle dividers when strictly needed)
- **Zero Hardcoded UI Colors:** Never introduce literal `#hex` colors or component-specific ad-hoc UI schemes. Fixed icon artwork identity colors are the narrow exception defined in §2; they must stay in `ColoredIcons`, never spread into control or surface styling.

---

## 4. Universal Theme Compatibility

Every component and surface must work out-of-the-box across all active Hydra theme modes:

- **Material 2021** (dynamic algorithmic tonal palettes)
- **Material 2025** (spec-compliant M3 Vibrant, Tonal Spot, Neutral, Expressive)
- **Classic** (authored static palettes)
- **Tinted** (surface post-processing engine)
- **Light & Dark modes**

Do not branch styling on `surfaceStyle` or active theme name inside UI components; semantic tokens automatically adapt to the generated palette roles.

---

## 5. Primitive & Component Reuse

Reuse existing tested primitives before creating custom controls:

- **Settings & Grouping:** `NSettingsGroupCard`, `NSettingsGroupNav`, `NCard`, `NBox`
- **Interactive Controls:** `NToggle`, `NButton`, `NIconButton`, `NValueSlider`, `NComboBox`, `NTextInput`
- **Typography & Icons:** `NText`, `NIcon`
- **Layout & Spacing:** Use proportional tokens from `Commons/Style.qml` (`Style.marginS`, `Style.marginM`, `Style.marginL`, `Style.marginXL`, `Style.controlHeight*`, `Style.iRadius*`).

### 5.1 Settings content hierarchy

- Scope is the content pane and its settings editors, not category/sidebar order. Preserve each existing setting, default, range, dependency, save boundary and operational action.
- Use one owner scroll (`SettingsContent`). Use `NSettingsGroupCard` for existing major groups and **open** `NSettingsSection` blocks for meaningful subsections. Short forms remain open; device lists, reorder editors, catalogs and monitor canvases retain their specialist layouts.
- Hierarchy is page title → major group → semantic subsection → control label → description. Subsections use a small `NColorIcon`, primary-colored heading and spacing, not another outlined card.
- Keep dependent controls adjacent to their master switch. Do not hide transaction recovery, external ownership, validation or busy states inside new disclosure controls.
- Local navigation opens and scrolls to its destination without closing other groups. Collapsing a group retains its loaded editors. Keep live collapsed summaries in the page's `summaries` map, separate from stable `groups` descriptors, so changing a value never recreates focused controls.
- Widget editor popups clamp to their parent viewport as well as the screen; keep their existing save/close/debounce contracts when adapting width and height.
- Compose only bounded, read-only examples: `NSettingsAppearancePreview`, `NSettingsWallpaperPreview`, typography samples and idle timeout summaries. Appearance replay animates only the local sample; wallpaper framing never changes a wallpaper or creates a monitor override. No automatic commands, sound, capture, locking or display changes for demonstration.
- Reflow from **available content width**, including at small windows and increased UI scale. Catalogs may become one column; threshold warning/critical controls remain paired; monitor actions and recovery controls wrap or stack. Reserve scrollbar space.
- Group and page fades use `Style.animationFast`; chevrons and hover use existing Style tokens. Do not animate the height of long forms. Reduced motion/performance modes retain instant, functional navigation.
- Retain translated search destinations when a label becomes a subsection heading. The search-index generator indexes specific `NSettingsSection` titles plus their nested controls; repeated generic `settings.content.*` headings are not extra results. Rebuild `Assets/settings-search-index.json` after reorganizing controls.


---

## 6. Layout Density Tiers

Tailor visual density to the interaction context:

1. **Comfortable:** Settings pages, onboarding, dialogue sheets, session menus (generous touch targets, descriptive secondary text).
2. **Dense:** Bar widgets, system tray menus, status indicators, monitor arrangement strips (compact, information-rich, tight padding).
3. **Visual / Specialized:** Window Switcher, Launcher, Wallpaper Color Lab, Monitor canvas (large preview tiles, prominent focus indicators, responsive card strips).

---

## 7. Responsiveness & Adaptive Sizing

- **No Horizontal Scrolling:** Windows and settings pages must reflow or wrap rather than requiring horizontal scrolling.
- **Flexible Wrapping:** Use `Flow` or responsive flex wrapping for chip bars and navigation options. Never force equal-width grid distribution (`distributeEvenly: true`) on variable-length text chips.
- **Scale Awareness:** Scale metrics proportionally with `Style.uiScaleRatio`. Specialized modals must preserve min/max bounds across different screen resolutions.

---

## 8. Framed Layout & Panel Docking Contract

### 8.1 The Frame as Canonical Spatial Architecture

- **Canonical Standard:** `barType = "framed"` is the canonical visual and spatial architecture of Hydra Shell, not merely a decorative bar appearance.
- **Structural Surface:** The frame is a permanent structural surface of the shell. Ordinary panels must visually originate from and dock into the frame as natural surface extensions rather than appearing as arbitrarily detached floating popups.
- **Docking by Default:** An ordinary shell panel must be born from a coherent frame edge or widget origin. A detached or floating panel is an explicit exception, never the default.

> **No new ordinary shell panel should default to screen-center without an explicit UX reason.**

- **Framed-First, Not Framed-Only:** All new shell experiences must be conceived and designed for the Framed architecture first. Detached, floating, or simple bar configurations remain supported for user customization and legacy transitions, but backward compatibility decisions must never compromise or dilute the Framed-first spatial design.

### 8.2 Design Identity & Aesthetic Invariants

Framed integration does not mean borrowing visual aesthetics from external shells:

- **Core Foundations:** Hydra strictly preserves Material You / Material 3 foundations, Google Pixel surface rhythms and tonal elevation, and Apple-grade spatial breathing room and quiet polish.
- **Caelestia Reference:** Architectural reference strictly for spatial coordination and panel coexistence concepts—**never** for visual styling.
- **Material Geometry:** Hydra expresses depth and docking purely through semantic Material tokens (`HydraColor.mSurface*`, `HydraColor.mSurfaceContainer*`), 4-state corner rendering (`PanelBackground`), and proportional spacing (`Style.margin*`). Hydra has **zero** aesthetic dependency on metaballs, organic blob shaders, or gooey fusion effects.
- **Surface Continuity:** Docked panels must preserve unbroken surface continuity with the frame, eliminating hairline gaps (via subpixel attachment overlap) and applying corner radii tailored to the contacted edge. When adjacent panels meet in future layouts, they must form a unified spatial composition rather than two overlapping, disconnected rectangles.

### 8.3 Canonical Frame Regions

Hydra organizes screen space into predictable canonical docking regions:

| Canonical Region | Primary Functional Assignment | Interaction & Docking Model |
| :--- | :--- | :--- |
| **Top Center** | Dashboard (Control Center) | Attached to top frame edge; downward expansion |
| **Center Right** | Session Menu | Attached to right frame edge; vertically centered |
| **Bottom Center** | Application Launcher | Attached to bottom frame edge; upward expansion |
| **Center Left** | Portal / Screen Share Picker | Attached to left frame edge; vertically centered |
| **Bottom Left** | Window Switcher (Alt-Tab) | Grounded to bottom-left frame corner |
| **Widget Anchor** | System Tray & Widget Popouts | Dynamically anchored to the initiating widget (`useButtonPosition`). Semantically follows widget position across bar layout changes |
| **Modal Overlay** | Polkit & Security Prompts | Centered / focused overlay stacked above active panel; non-dismissable by outside click |

*Reserved Regions:* **Top Left**, **Top Right**, and **Bottom Right** are currently unassigned and reserved for future shell capabilities.

> **Dynamic Anchoring Invariant:** The System Tray is **not** hardcoded to Top Left. Tray menus and widget popouts must dynamically anchor to their trigger widget. If the user moves or rearranges widgets on the bar, the panel follows that semantic origin.
>
> **Spatial Vocabulary:** Canonical regions define Hydra's standard spatial vocabulary and design intent, not an immutable lock preventing multiple compatible features over the shell's lifespan.

### 8.4 Semantic Relationships Before Positioning

Before assigning two panels to the same region or defining their geometry, evaluate their workflow dependencies:

- **Functional Dependency:** If Panel B depends visually or functionally on Panel A remaining open (e.g., Launcher initiates an operation triggering a Polkit authentication prompt), they must **never** use a mutually exclusive lifecycle. Panel B must act as a modal overlay (`modalOverlay = true`) that stacks over Panel A.
- **Independent Roles:** If two panels serve independent workflows and never need to be active simultaneously, sharing a canonical region and replacing each other is standard and expected.
- **Integrated Decision:** Spatial location must always be decided in conjunction with the semantic relationship between panels.

### 8.5 Collision & Coexistence Strategies

Hydra defines four conceptual behaviors for spatial coordination:

1. **REPLACE:** One panel replaces another when they occupy the same role or region and do not need to coexist.
2. **SHRINK:** Panels occupying opposing frame regions dynamically reduce their available area to avoid collision (e.g., Dashboard expanding from Top Center while Launcher is open at Bottom Center).
3. **SHIFT:** Neighboring panels displace or translate laterally to yield space along shared edges.
4. **OVERLAY:** Strictly reserved for genuinely modal or dependent interactions (e.g., Polkit authentication). Never use overlay as a shortcut to bypass geometric conflict resolution.

> **Rule:** Ordinary panels must not simply stack under or over one another by arbitrary z-order when their geometries collide. Spatial conflicts must resolve through replacement, responsive resizing, translation, or an explicit modal contract.

### 8.6 Current State vs. Architectural Direction

- **Current Implementation Baseline:** Hydra's current runtime (`PanelService`) operates primarily on a single-panel baseline: one normal `openedPanel`, one transitioning `closingPanel`, and one stacked `modalPanel`.
- **Implemented Framed Placement:** Dashboard docks at Top Center, Launcher at Bottom Center, and Session Menu at Center Right. These hosts opt out of widget/click positioning through `SmartPanel.allowButtonPosition = false` in Framed mode and force attachment even when the saved global attachment preference is disabled. Dashboard content also enables attachment explicitly, so a saved `controlCenter.detached = true` cannot introduce a frame gap.
- **Defaults & Compatibility:** `Commons/Settings.qml` and `Assets/settings-default.json` default to `controlCenter.position = "top_center"`, `controlCenter.detached = false`, `appLauncher.position = "bottom_center"`, and `sessionMenu.position = "center_right"`. Explicit saved preferences are not migrated or reset; outside Framed mode they remain effective. Launcher `overviewLayer` retains its separate window and lifecycle.
- **Design Contract Today:** The rules in this section constitute Hydra's binding **Design Contract**. All new features must choose their canonical frame region and respect frame docking immediately.
- **Future Spatial Infrastructure:** Advanced automated layout management, dynamic neighbor negotiation, multi-panel collision resolution, and multiple simultaneous normal panels belong to the upcoming spatial infrastructure phase.
- **Zero Debt Policy:** No new feature may deliberately introduce technical debt by defaulting to legacy arbitrary center popups.

### 8.7 Panel Docking Contract Checklist

Every new shell panel, drawer, or surface must satisfy this mandatory checklist during design:

1. **Canonical Region:** Which canonical frame region does this panel inhabit?
2. **Docking Mode:** Is it edge-attached, widget-anchored, modal overlay, or is there an evidenced UX justification for floating?
3. **Coexistence Scope:** Which panels might need to remain open concurrently with this surface?
4. **Conflict Resolution:** In case of spatial collision, does it replace, shrink, shift, or overlay?
5. **Workflow Dependency:** Does a functional dependency exist between this panel and the trigger surface that opened it?
6. **Orientation & Scale Invariance:** Does the docking geometry behave reliably across different bar positions (top, bottom, left, right) and screen resolutions?
7. **Design System Tokens:** Does the surface honor Hydra's Material 3 tokens (`HydraColor.mSurface*`), frame-continuous corner states, and standard spacing?

> **"Panel placement is part of the feature design, not an afterthought."**

---

## 9. Motion & State Continuity

- Motion must be intentional: explain state transitions (enter, exit, expand, select) rather than decorate.
- **Durations:** Panels/content use `Style.animationFast` and `Style.animationNormal`. Pointer layers use `Style.hoverEnterDuration` / `Style.hoverLeaveDuration` (100ms / 30ms at normal speed), including the existing reduced-motion/performance gates.
- **Easing:** Prefer standard material easing curves. Avoid aggressive overshoot, bouncing, or physics simulation unless explicitly modeling tactile gestures.
- **Asymmetric Timing:** Shared hover and highlight states must enter smoothly and leave rapidly to eliminate sluggish pointer trails.
- **Independent states:** Selection, `hot`, expansion and the current application/source are persistent bases, never replaced by hover. Press takes precedence over hover; disabled controls retain their status but suppress transient layers and focus outlines. Badges, urgency and recording/error colors remain semantic status, not hover artwork.
- **Shared painting:** Use `NStateLayer` for interactive backgrounds, preserving the owner's capsule, row, tile or button geometry. It owns painting only; input, activation and persistent state stay with the existing control. Its default focus policy is `Qt.NoFocus`; interactive owners explicitly opt into `Qt.StrongFocus`.
- **Alpha composition:** Transparent/translucent surfaces use source-over weights through `Style.interactionTint`. Do not apply `Qt.tint` directly to a transparent base: its straight-RGB result can multiply the ink opacity again during rendering, producing faint/dark hover instead of a readable layer.
- **State strength and contrast:** `Style.interactionColor` uses 8% hover / 12% press from semantic palette roles. One ink is chosen for both states, so a transition does not reverse direction. Preserve text contrast of at least 4.5:1 where the base already supports it; do not worsen low-contrast authored/custom pairs or rewrite the palette. `Style.focusOutlineColor` targets a stroke readable across rest/press (3:1), deriving a neutral tone when existing roles are insufficient; do not add decorative permanent outlines or glows.
- **Focus is not selection:** Button/navigation focus comes from `Control.visualFocus`, not `activeFocus` after a click. Keep its inset stroke separate from the persistent fill. Text/numeric editors may still acknowledge all editing focus. Popup current/cursor feedback must remain distinct from the saved option, which keeps its tonal fill and check mark.
- **Specialized shapes:** Existing per-corner `NBox` surfaces use `Style.interactionColor` without changing their geometry or menu anchoring. Bar hit targets may exceed their visual button: paint only the visual surface. Solid tiny indicators, scrollbar handles, drag boundaries and domain-specific status marks retain their own roles.
- **Regression surface:** `Scripts/dev/tests/interaction-states.qml` renders the actual primitives and Settings sidebar through a private checkout facade/XDG environment. Its `highlightLab` IPC exposes state capture and independent hover, press, disabled, keyboard focus, palette, scale and popup-cursor inspection; it is not imported by the live shell.

---

## 10. Anti-Patterns to Avoid

- **Boxes inside boxes:** Nesting bordered cards inside bordered cards.
- **Dividers as defaults:** Separating list items with solid lines when spacing already provides clear visual separation.
- **Permanent outlines:** Framing every button, chip, and card with high-contrast borders.
- **Micro-tuning loops:** Shifting margins by 1px back and forth without referencing standard tokens.
- **Duplicated interaction primitives:** Creating custom button/slider implementations when `NButton` or `NValueSlider` exists.
- **Arbitrary center popups:** Defaulting ordinary shell panels to floating in the center of the screen without an explicit UX rationale.
- **Z-order collision stacking:** Stacking overlapping panels on top of each other by arbitrary z-order instead of defining explicit spatial resolution (replace, shrink, shift, or modal overlay).
- **Blob and metaball effects:** Relying on organic blob or gooey shape filters instead of clean Material geometric continuity.

---

## 11. Human Visual Verification & Polish Policy

> **Visible UI changes are NOT complete until visually inspected in the real preview/runtime.**<br>
> Unit and functional tests alone are not proof of visual readiness.

- **Agent Anti-Loop Rule:**
  1. Implement a clean, token-based design adhering to these guidelines.
  2. Launch and observe the live preview (`Scripts/dev/lab-preview.sh` or local runtime).
  3. Perform **one** focused pass to resolve visual discrepancies, clipping, or alignment issues.
  4. Stop and request human visual review. Do not iterate endlessly on subjective aesthetic minutiae.
