# Hydra Design Tokens Reference

This reference catalogs **only verified tokens** present in Hydra's current source code.
Do not invent tokens (such as `Style.spacingM`, `Color.mOutlineVariant`, or `Theme.*`). If a token does not exist in this catalog, declare it as nonexistent and use proportional spacing or composition.

---

## 1. Color Tokens (`Commons/Color.qml`)

All color tokens reside in the singleton `qs.Commons.Color` (or `Color.*`).
Property names are prefixed with `m` to avoid collisions with QML signal handlers.

### Key Accent Roles
| Token | Type | Description |
| :--- | :--- | :--- |
| `Color.mPrimary` | `color` | Main brand/accent color; prominent interactive states |
| `Color.mOnPrimary` | `color` | Text/icons rendered over `mPrimary` |
| `Color.mSecondary` | `color` | Secondary accent color; category badges and icons |
| `Color.mOnSecondary` | `color` | Text/icons rendered over `mSecondary` |
| `Color.mTertiary` | `color` | Tertiary accent color; balancing highlights |
| `Color.mOnTertiary` | `color` | Text/icons rendered over `mTertiary` |

### Utility & Error Roles
| Token | Type | Description |
| :--- | :--- | :--- |
| `Color.mError` | `color` | Error, danger, and critical destructive actions |
| `Color.mOnError` | `color` | Text/icons rendered over `mError` |
| `Color.mErrorContainer` | `color` | Tonal error container background |
| `Color.mOnErrorContainer` | `color` | Text/icons rendered over `mErrorContainer` |

### Base Surfaces & Text Roles
| Token | Type | Description |
| :--- | :--- | :--- |
| `Color.mSurface` | `color` | Base desktop surface |
| `Color.mOnSurface` | `color` | High-emphasis foreground text, titles, active labels |
| `Color.mSurfaceVariant` | `color` | Alternative surface tone; subtle card tracks |
| `Color.mOnSurfaceVariant` | `color` | Medium-emphasis text, descriptions, hints, disabled glyphs |
| `Color.mOutline` | `color` | Semantic border and focus ring color |
| `Color.mShadow` | `color` | Base shadow tint |

### Surface Container Hierarchy
| Token | Type | Description |
| :--- | :--- | :--- |
| `Color.mSurfaceContainerLowest` | `color` | Lowest/darkest surface step |
| `Color.mSurfaceContainerLow` | `color` | Frame and bar background (`BarBackground.qml`) |
| `Color.mSurfaceContainer` | `color` | Standard shell panel background (`SmartPanel.qml`) |
| `Color.mSurfaceContainerHigh` | `color` | Elevated container cards (`NBox.qml`), modal overlays |
| `Color.mSurfaceContainerHighest`| `color` | Top-level popouts, hover layers, active input tracks |

### Tonal Accent Containers
| Token | Type | Description |
| :--- | :--- | :--- |
| `Color.mPrimaryContainer` | `color` | Tonal primary container (keyboard selection, prominent cards) |
| `Color.mOnPrimaryContainer` | `color` | Text/icons rendered over `mPrimaryContainer` |
| `Color.mSecondaryContainer` | `color` | Tonal secondary container (settings group icon boxes) |
| `Color.mOnSecondaryContainer` | `color` | Text/icons rendered over `mSecondaryContainer` |
| `Color.mTertiaryContainer` | `color` | Tonal tertiary container |
| `Color.mOnTertiaryContainer` | `color` | Text/icons rendered over `mTertiaryContainer` |

### State & Interaction Colors
| Token | Type | Description |
| :--- | :--- | :--- |
| `Color.mHover` | `color` | Pointer hover highlight color |
| `Color.mOnHover` | `color` | Foreground text/icons over `mHover` |

### Color Utility Functions
- `Color.resolveColorKey(key)` — Resolves `"primary"`, `"secondary"`, `"tertiary"`, or `"error"` to its color token (falls back to `mOnSurface`).
- `Color.resolveOnColorKey(key)` — Resolves matching on-color (`mOnPrimary`, `mOnSecondary`, etc., falling back to `mSurface`).
- `Color.resolveColorKeyOptional(key)` — Same as `resolveColorKey`, but falls back to `"transparent"`.
- `Color.adaptiveOpacity(baseOpacity)` — Computes contrast-aware opacity (e.g., reduces opacity in light mode).
- `Color.smartAlpha(baseColor, minAlpha)` — Computes opacity respecting performance mode and translucency settings.

---

## 2. Radii Tokens (`Commons/Style.qml`)

All radii scale dynamically through user-configurable ratios in `Settings`.

### Container Radii (`Style.radius*`)
For cards, layout containers, panels, and sheets. Scaled by `Settings.data.general.radiusRatio`:
| Token | Base Value | Scaled Formula | Usage |
| :--- | :--- | :--- | :--- |
| `Style.radiusXXXS` | 3px | `Math.round(3 * radiusRatio)` | Micro badges |
| `Style.radiusXXS` | 4px | `Math.round(4 * radiusRatio)` | Small chips |
| `Style.radiusXS` | 8px | `Math.round(8 * radiusRatio)` | Sub-containers |
| `Style.radiusS` | 12px | `Math.round(12 * radiusRatio)` | Popup menus, standard cards |
| `Style.radiusM` | 16px | `Math.round(16 * radiusRatio)` | Group cards (`NBox.qml`) |
| `Style.radiusL` | 20px | `Math.round(20 * radiusRatio)` | Shell panels (`SmartPanel.qml`) |
| `Style.screenRadius` | 20px | `Math.round(20 * screenRadiusRatio)` | Outer frame display corner cutouts |

### Input Radii (`Style.iRadius*`)
For interactive controls (buttons, toggles, text fields). Scaled by `Settings.data.general.iRadiusRatio`:
| Token | Base Value | Scaled Formula | Usage |
| :--- | :--- | :--- | :--- |
| `Style.iRadiusXXXS`| 3px | `Math.round(3 * iRadiusRatio)` | Miniature controls |
| `Style.iRadiusXXS` | 4px | `Math.round(4 * iRadiusRatio)` | Small toggles |
| `Style.iRadiusXS` | 8px | `Math.round(8 * iRadiusRatio)` | Compact buttons |
| `Style.iRadiusS` | 12px | `Math.round(12 * iRadiusRatio)` | Standard buttons (`NButton.qml`) |
| `Style.iRadiusM` | 16px | `Math.round(16 * iRadiusRatio)` | Medium chips & icon badges |
| `Style.iRadiusL` | 20px | `Math.round(20 * iRadiusRatio)` | Pill buttons, icon buttons (`NIconButton`) |

---

## 3. Spacing & Margin Tokens (`Commons/Style.qml`)

Spacing tokens scale with `Style.uiScaleRatio` (`Settings.data.general.scaleRatio`).
**Notice:** Hydra uses `Style.margin*`, NOT `Style.spacing*`!

### Standard Spacing Tokens
| Token | Base Value | Formula |
| :--- | :--- | :--- |
| `Style.marginXXXS` | 1px | `Math.round(1 * uiScaleRatio)` |
| `Style.marginXXS` | 2px | `Math.round(2 * uiScaleRatio)` |
| `Style.marginXS` | 4px | `Math.round(4 * uiScaleRatio)` |
| `Style.marginS` | 6px | `Math.round(6 * uiScaleRatio)` |
| `Style.marginM` | 9px | `Math.round(9 * uiScaleRatio)` |
| `Style.marginL` | 13px | `Math.round(13 * uiScaleRatio)` |
| `Style.marginXL` | 18px | `Math.round(18 * uiScaleRatio)` |

### Container Sizing Margins (`Style.margin2*`)
Precomputed double margins for parent sizing (e.g. `height: content.implicitHeight + Style.margin2M`):
- `Style.margin2XXXS`, `Style.margin2XXS`, `Style.margin2XS`, `Style.margin2S`, `Style.margin2M`, `Style.margin2L`, `Style.margin2XL`.

---

## 4. Typography Tokens (`Commons/Style.qml`)

### Font Sizes
| Token | Value | Intended Usage |
| :--- | :--- | :--- |
| `Style.fontSizeXXS` | 8pt | Bar miniature indicators, tiny status labels |
| `Style.fontSizeXS` | 9pt | Compact pill labels, secondary timestamps |
| `Style.fontSizeS` | 10pt | Card metadata, helper notes |
| `Style.fontSizeM` | 11pt | Default UI body text, buttons, form inputs |
| `Style.fontSizeL` | 13pt | Prominent app titles, primary action buttons |
| `Style.fontSizeXL` | 16pt | Card headers, subsection titles |
| `Style.fontSizeXXL` | 18pt | Panel headers, modal sheet titles |
| `Style.fontSizeXXXL`| 24pt | Big hero numbers, clock displays |

### Font Weights
| Token | Value | Weight |
| :--- | :--- | :--- |
| `Style.fontWeightRegular` | 400 | Regular body text |
| `Style.fontWeightMedium` | 500 | Default UI labels, descriptions |
| `Style.fontWeightSemiBold`| 600 | Buttons, card headings, subheaders |
| `Style.fontWeightBold` | 700 | Hero titles, display headers |

---

## 5. Border & Outline Tokens (`Commons/Style.qml`)

| Token | Base Value | Scaled Formula / Value |
| :--- | :--- | :--- |
| `Style.borderS` | 1px | `Math.max(1, Math.round(1 * uiScaleRatio))` |
| `Style.borderM` | 2px | `Math.max(1, Math.round(2 * uiScaleRatio))` |
| `Style.borderL` | 3px | `Math.max(1, Math.round(3 * uiScaleRatio))` |
| `Style.boxBorderColor` | `color` | `Settings.data.ui.boxBorderEnabled ? Color.mOutline : "transparent"` |
| `Style.capsuleBorderColor` | `color` | `Settings.data.bar.showOutline ? Color.mPrimary : "transparent"` |
| `Style.capsuleBorderWidth` | `int` | `Settings.data.bar.showOutline ? Style.borderS : 0` |

---

## 6. Motion & Animation Tokens (`Commons/Style.qml`)

Durations are in milliseconds and adapt to `animationSpeed` and `PowerProfileService.hydraPerformanceMode` (durations become 0 when animations are disabled).

| Token | Base Duration | Formula / Notes |
| :--- | :--- | :--- |
| `Style.animationFaster` | 75ms | Scaled by `animationSpeed` (micro-interactions) |
| `Style.animationFast` | 150ms | Scaled by `animationSpeed` (toggle switches, collapse/expand) |
| `Style.animationNormal` | 300ms | Scaled by `animationSpeed` (standard transitions, overlays) |
| `Style.animationSlow` | 450ms | Scaled by `animationSpeed` (major panel movements) |
| `Style.animationSlowest`| 750ms | Scaled by `animationSpeed` (color palette transitions) |
| `Style.hoverEnterDuration` | 100ms | Smooth enter transition |
| `Style.hoverLeaveDuration` | 30ms | Rapid leave transition (eliminates sluggish pointer trailing) |
| `Style.tooltipDelay` | 300ms | Standard hover tooltip delay |
| `Style.tooltipDelayLong`| 1200ms | Extended tooltip delay |
| `Style.pillDelay` | 500ms | Pill notification delay |

---

## 7. Opacity & Shadow Tokens (`Commons/Style.qml`)

| Token | Value | Purpose |
| :--- | :--- | :--- |
| `Style.opacityNone` | 0.0 | Fully transparent |
| `Style.opacityLight` | 0.25 | Subtle wash |
| `Style.opacityMedium` | 0.50 | Disabled state / mid overlay |
| `Style.opacityHeavy` | 0.75 | Dimming scrim |
| `Style.opacityAlmost` | 0.95 | Nearly opaque |
| `Style.opacityFull` | 1.0 | Fully opaque |
| `Style.effectivePanelOpacity` | `real` | Computed panel opacity (respects performance mode) |
| `Style.effectiveBarOpacity` | `real` | Computed bar opacity (respects performance mode) |
| `Style.shadowOpacity` | 0.85 | Base shadow intensity |
| `Style.shadowBlur` | 1.0 | Normalized blur multiplier |
| `Style.shadowBlurMax` | 22px | Maximum shadow radius |

---

## 8. Widget & Layout Sizing (`Commons/Style.qml`)

| Token / Function | Value / Return | Description |
| :--- | :--- | :--- |
| `Style.baseWidgetSize` | 33px | Standard bar widget icon/touch target size |
| `Style.sliderWidth` | 200px | Standard slider track width |
| `Style.barHeight` | `real` | Active bar height calculated from density and orientation |
| `Style.capsuleHeight` | `real` | Inner capsule height (smaller than barHeight) |
| `Style.pixelAlignCenter(container, content)` | `int` | Integer pixel alignment to prevent fractional blur |
| `Style.toOdd(n)` | `int` | Rounds down to nearest odd integer |
| `Style.toEven(n)` | `int` | Rounds down to nearest even integer |

---

## 9. Verified Non-Existent Tokens

The following names are NOT defined in Hydra. Do NOT use them:
- `Color.mOutlineVariant` — Not in `Color.qml`. (Use `Color.mSurfaceVariant` or clean spacing).
- `Style.spacing*` — Spacing tokens in Hydra are named `Style.margin*`.
- `Style.fontSize*` sizes like `Style.fontSizeBase` or `Style.fontSizeHeader` — Use `Style.fontSizeM`, `Style.fontSizeXL`, etc.
- `Theme.*` — Theming is in `Color.*` and `Style.*`. There is no `Theme` singleton.
- `NCard.qml` — Does not exist as a separate widget file. The container primitive is `NBox.qml` or `NSettingsGroupCard.qml`.
