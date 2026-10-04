# Hydra UI/UX Design Guidelines

Durable design and interaction guidelines for Hydra Shell. All user-visible surfaces, settings, panels, OSDs, and controls must adhere to these principles.

---

## 1. Visual Identity & Design Foundation

- **Primary Foundation:** Material You / Material 3 adapted to Hydra's distinctive visual identity.
- **Composition & Surface References:**
  - Modern Android / Pixel UI serves as the primary reference for surface grouping, tonal elevation, and natural interaction rhythms.
  - Modern Apple / macOS / iOS serves as a secondary reference for breathing room, optical clarity, hierarchy, progressive disclosure, and quiet polish.
- **Relationship with Noctalia:**
  - **Noctalia V4:** Historical functional reference only. **NEVER** treat Noctalia V4 as a visual or styling reference.
  - **Noctalia V5:** Behavioral, architectural, and structural reference when useful. **NEVER** clone Noctalia V5 aesthetically. Hydra is not recolored Noctalia.

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

---

## 3. Semantic Surfaces & Color Tokens

All UI colors must derive strictly from Hydra's design tokens in `Commons/Color.qml` and `Commons/Style.qml`:

- **Surfaces & Containers:**
  - `Color.mSurface`, `Color.mSurfaceVariant`, `Color.mSurfaceContainerLowest`, `Color.mSurfaceContainerLow`, `Color.mSurfaceContainer`, `Color.mSurfaceContainerHigh`, `Color.mSurfaceContainerHighest`
- **Tonal Brand Accents:**
  - `Color.mPrimary`, `Color.mOnPrimary`, `Color.mPrimaryContainer`, `Color.mOnPrimaryContainer`
  - `Color.mSecondary`, `Color.mSecondaryContainer`, `Color.mTertiary`, `Color.mTertiaryContainer`
- **Text & Icon Roles:**
  - `Color.mOnSurface` (high emphasis: titles, active text)
  - `Color.mOnSurfaceVariant` (medium emphasis: descriptions, labels, hints)
  - `Color.mOutline`, `Color.mOutlineVariant` (semantic borders, subtle dividers when strictly needed)
- **Zero Hardcoded Colors:** Never introduce literal `#hex` colors or component-specific ad-hoc color schemes.

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

## 8. Motion & State Continuity

- Motion must be intentional: explain state transitions (enter, exit, expand, select) rather than decorate.
- **Durations:** Keep animations short and snappy (150ms to 250ms). Use `Style.animationFast` and `Style.animationNormal`.
- **Easing:** Prefer standard material easing curves. Avoid aggressive overshoot, bouncing, or physics simulation unless explicitly modeling tactile gestures.
- **Asymmetric Timing:** Shared hover and highlight states must enter smoothly and leave rapidly to eliminate sluggish pointer trails.

---

## 9. Anti-Patterns to Avoid

- **Boxes inside boxes:** Nesting bordered cards inside bordered cards.
- **Dividers as defaults:** Separating list items with solid lines when spacing already provides clear visual separation.
- **Permanent outlines:** Framing every button, chip, and card with high-contrast borders.
- **Micro-tuning loops:** Shifting margins by 1px back and forth without referencing standard tokens.
- **Duplicated interaction primitives:** Creating custom button/slider implementations when `NButton` or `NValueSlider` exists.

---

## 10. Human Visual Verification & Polish Policy

> **Visible UI changes are NOT complete until visually inspected in the real preview/runtime.**<br>
> Unit and functional tests alone are not proof of visual readiness.

- **Agent Anti-Loop Rule:**
  1. Implement a clean, token-based design adhering to these guidelines.
  2. Launch and observe the live preview (`Scripts/dev/lab-preview.sh` or local runtime).
  3. Perform **one** focused pass to resolve visual discrepancies, clipping, or alignment issues.
  4. Stop and request human visual review. Do not iterate endlessly on subjective aesthetic minutiae.
