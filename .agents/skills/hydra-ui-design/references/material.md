# Material Design 3 in Hydra Shell

This document defines how Google's Material Design 3 (Material You / M3 Expressive) is adapted and applied within Hydra Shell.

---

## 1. The Hydra Material Paradigm

Hydra adopts Material 3 as its core visual foundation while tailoring it to an advanced Wayland desktop shell:

- **Semantic Role Purity:** All UI coloring, elevation, and hierarchy derive from semantic token roles rather than arbitrary aesthetic choices.
- **Tonal Elevation:** Surfaces achieve depth, grouping, and separation through tonal surface steps (`mSurfaceContainer*`), replacing heavy drop shadows and high-contrast structural borders.
- **The Desktop Context:** While Android mobile informs surface grouping and interaction cadence, desktop shell mechanics demand keyboard navigation, high-density widgets, cursor hover states, and multi-monitor awareness.

### Critical Implementation Rule
- **Material 3 Semantics:** ALWAYS APPLY (color roles, tonal containers, shape tokens, typography scales, contrast).
- **Jetpack Compose / Kotlin APIs:** NEVER USE (Hydra is Qt 6 / QML / Quickshell).
- **Flutter / Web / MUI / Tailwind APIs:** NEVER USE.

---

## 2. Semantic Color System

All colors are exposed through the singleton `qs.Commons.Color` (`Commons/Color.qml`).

### Why the `m` Prefix?
In QML, property names starting with `on` (such as `onPrimary` or `onSurface`) are interpreted by the QML engine as signal handlers for hypothetical signals named `primary` or `surface`. To prevent parse-time signal collisions and binding failures, **all Material color properties in Hydra are prefixed with `m`** (e.g., `mPrimary`, `mOnPrimary`, `mSurface`, `mOnSurface`).

### Color Roles Mapping

| Material Role | Hydra Token | Purpose & Application |
| :--- | :--- | :--- |
| **Primary** | `Color.mPrimary` | High-emphasis fills, active toggles, highlighted states, primary accents |
| **On-Primary** | `Color.mOnPrimary` | High-contrast text/glyphs rendered directly atop `mPrimary` |
| **Primary Container** | `Color.mPrimaryContainer` | Standout accent container (keyboard active selection, prominent cards) |
| **On-Primary Container** | `Color.mOnPrimaryContainer` | Text/glyphs rendered directly atop `mPrimaryContainer` |
| **Secondary** | `Color.mSecondary` | Less prominent accent; category icons, secondary chips |
| **On-Secondary** | `Color.mOnSecondary` | Text/glyphs rendered directly atop `mSecondary` |
| **Secondary Container** | `Color.mSecondaryContainer` | Tonal secondary backgrounds (e.g. settings section icon boxes) |
| **On-Secondary Container**| `Color.mOnSecondaryContainer`| Text/glyphs rendered directly atop `mSecondaryContainer` |
| **Tertiary** | `Color.mTertiary` | Complementary accent for balancing primary/secondary tones |
| **Tertiary Container** | `Color.mTertiaryContainer` | Tonal tertiary container for specialized status or badges |
| **On-Tertiary Container** | `Color.mOnTertiaryContainer` | Text/glyphs rendered directly atop `mTertiaryContainer` |
| **Surface** | `Color.mSurface` | Base desktop surface background |
| **On-Surface** | `Color.mOnSurface` | High-emphasis text (titles, values, active labels) on surfaces |
| **Surface Variant** | `Color.mSurfaceVariant` | Alternative surface tone; inactive track fills, subtle backgrounds |
| **On-Surface Variant** | `Color.mOnSurfaceVariant` | Medium-emphasis text (descriptions, hints, secondary labels, disabled icons) |
| **Outline** | `Color.mOutline` | Semantic borders (focus rings, error highlights, active selections) |
| **Shadow** | `Color.mShadow` | Elevation drop shadow tint (used in `NDropShadow`) |
| **Error** | `Color.mError` | Critical alerts, dangerous actions, failure states |
| **On-Error** | `Color.mOnError` | Text/glyphs rendered directly atop `mError` |
| **Error Container** | `Color.mErrorContainer` | Tonal fill for error notices and warnings |
| **On-Error Container** | `Color.mOnErrorContainer` | Text/glyphs rendered directly atop `mErrorContainer` |
| **Hover / On-Hover** | `Color.mHover`, `Color.mOnHover` | Pointer hover accents and state layers |

*(Note: `Color.mOutlineVariant` does not exist in the current runtime code. For subtle dividing lines, use proportional spacing or `mSurfaceVariant` rather than inventing missing tokens).*

---

## 3. Tonal Surface Container Hierarchy

Material 3 establishes depth through 5 container steps. In Hydra, these are resolved algorithmically or via generated palette files:

```
[ mSurfaceContainerLowest ]  -- Darkest/lowest container
        ↓
[ mSurfaceContainerLow ]     -- Bar background (`BarBackground.qml`), subtle cards
        ↓
[ mSurfaceContainer ]        -- Standard panel background (`SmartPanel.qml`), expanded settings cards
        ↓
[ mSurfaceContainerHigh ]    -- Elevated sub-cards (`NBox.qml`), modal overlays, active inputs
        ↓
[ mSurfaceContainerHighest ] -- Top-level hover states, popup flyouts, active toggle tracks
```

### Usage Guidelines
1. **Frame & Bar:** Uses `Color.mSurfaceContainerLow`.
2. **Docked Panel Surfaces:** Default to `Color.mSurfaceContainer`.
3. **Modal Overlays:** Use `Color.mSurfaceContainerHigh` to visually elevate above the underlying panel.
4. **Grouped Cards & Sub-boxes:** Use `NBox` (`Color.mSurfaceContainerHigh`) inside a panel to delineate functional groups.
5. **Interactive Controls:** Use `Color.mSurfaceContainerHighest` for hover states, inactive toggle tracks, or pill chips.

---

## 4. Shapes & Radii Hierarchy

Hydra separates radii into two distinct semantic categories in `Commons/Style.qml`:

### Container Radii (`Style.radius*`)
Used for structural panels, cards, sheets, and layout surfaces. Scaled by `Settings.data.general.radiusRatio`:
- `radiusXXXS` (3px) / `radiusXXS` (4px): Micro badges and indicators.
- `radiusXS` (8px): Compact sub-elements.
- `radiusS` (12px): Standard cards and popup menus.
- `radiusM` (16px): Large container cards (`NBox.qml`).
- `radiusL` (20px): Primary shell panel corners (`SmartPanel.qml`, `PanelBackground.qml`).
- `screenRadius` (20px): Outer display corner cutouts in Framed mode.

### Input Radii (`Style.iRadius*`)
Used for interactive controls (buttons, toggles, text inputs, sliders). Scaled by `Settings.data.general.iRadiusRatio`:
- `iRadiusS` (12px): Standard buttons (`NButton.qml`).
- `iRadiusM` (16px): Medium icon badges and settings icon chips.
- `iRadiusL` (20px): Fully rounded pill buttons and icon buttons (`NIconButton.qml`).

---

## 5. Typography Scale

Hydra adapts Material 3 typographic hierarchy through `Style.fontSize*` and `Style.fontWeight*`:

| Role | Font Size Token | Font Weight Token | Typical Application |
| :--- | :--- | :--- | :--- |
| **Display / Hero** | `Style.fontSizeXXXL` (24px) | `Style.fontWeightBold` (700) | Big clocks, lockscreen headers |
| **Headline / Title** | `Style.fontSizeXXL` (18px) | `Style.fontWeightSemiBold` (600) | Panel main headers, modal titles |
| **Subheading** | `Style.fontSizeXL` (16px) | `Style.fontWeightSemiBold` (600) | Card titles, group section headings |
| **Body Large** | `Style.fontSizeL` (13px) | `Style.fontWeightMedium` (500) | Launcher app names, primary button labels |
| **Body Medium** | `Style.fontSizeM` (11px) | `Style.fontWeightMedium` (500) | Default UI labels, descriptions, inputs |
| **Body Small** | `Style.fontSizeS` (10px) | `Style.fontWeightRegular` (400) | Secondary metadata, timestamps |
| **Caption / Badge** | `Style.fontSizeXS` (9px) | `Style.fontWeightRegular` (400) | Compact pill labels, status indicators |
| **Micro Caption** | `Style.fontSizeXXS` (8px) | `Style.fontWeightRegular` (400) | Bar miniature text, dense indicators |

---

## 6. Layout Density Tiers

1. **Comfortable:** Settings pages, setup wizards, session dialogs. Generous padding (`Style.marginXL`), descriptive subtitles, larger touch targets.
2. **Dense:** Bar widgets, system tray menus, status indicators. Compact padding (`Style.marginS`), tight horizontal flow, high information density.
3. **Visual / Specialized:** Application Launcher, Window Switcher, Media player cards. Prominent iconography, focused layout, fluid navigation.

---

## 7. Universal Theme Compatibility

Hydra supports dynamic wallpaper-derived color extraction and multiple palette engines:
- **Material 2021:** Algorithmic tonal palettes generated dynamically from wallpaper seeds.
- **Material 2025:** Spec-compliant Material You schemes (`Tonal Spot`, `M3 Vibrant`, `Expressive`, `Neutral`).
- **Classic:** Handcrafted, curated static color schemes.
- **Tinted:** Surface post-processing engine adjusting surface luminance and temperature.
- **Light & Dark Modes:** Automatic contrast calculation (`adaptiveOpacity` makes light mode surfaces more translucent).

### Golden Rule for UI Components
**NEVER branch styling on `surfaceStyle` or active theme name inside UI components.**
Components bind strictly to `Color.m*` tokens. The theming engine automatically resolves the active theme into the correct semantic token values.
