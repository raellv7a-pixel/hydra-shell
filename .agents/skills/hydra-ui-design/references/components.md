# Hydra Reusable Components Catalog

This catalog documents the verified reusable UI primitives located in `Widgets/` (`qs.Widgets`).
Always reuse these tested primitives instead of assembling ad-hoc combinations (e.g. `Rectangle + MouseArea` or raw `Text`).

---

## 1. Grouping & Layout Containers

### `NSettingsGroupCard`
- **Path:** `Widgets/NSettingsGroupCard.qml`
- **Purpose:** Collapsible settings section card with icon chip, title, description, and expandable content body.
- **When to reuse:** Settings pages, configuration dialogs, complex accordion groups.
- **When NOT to reuse:** Compact popups, dense widgets, or non-expandable cards.
- **Category mark:** Uses `NColorIcon`; prominent heading, wrapped description, visible keyboard focus and accessible checked state. Collapsing preserves loaded controls and owner-managed expansion state. Optional `summary` replaces the description while collapsed; body appearance fades without height animation.

### `NSettingsGroupPage`
- **Path:** `Widgets/NSettingsGroupPage.qml`
- **Purpose:** Shared vertical settings page with `groups`, stable `pageKey`, session expansion state and search/deep-link reveal hooks.
- **Optional overview:** Supply `header: Component { ... }` for content preceding navigation. The default is absent; do not use this to replace the page's scroll or controls.
- **Navigation:** `jump(key)` and search reveal open the destination without closing other groups. `toggle(key, open)` changes only that group's session state.
- **Live summaries:** Bind the `summaries` map by group key; keep `groups` stable so summary changes do not recreate editors.
- **Example consumer:** `Modules/Panels/Settings/Tabs/GeneralTab.qml`.

### `NSettingsGroupNav`
- **Path:** `Widgets/NSettingsGroupNav.qml`
- **Purpose:** Horizontal jump chip navigation for quickly scrolling to sections within a settings page.
- **When to reuse:** At the top of settings pages with multiple collapsible cards.
- **When NOT to reuse:** Traditional tab navigation or single-topic dialogs.
- **Keyboard:** Enter/Space activates the destination; Left/Right and Home/End move focus between chips.

### `NBox`
- **Path:** `Widgets/NBox.qml`
- **Purpose:** Base rounded group container elevated above its parent panel (`HydraColor.mSurfaceContainerHigh`), supporting per-corner radius overrides.
- **When to reuse:** Wrapping related controls, form rows, or card strips within panels and settings. This is Hydra's **primary card primitive** (there is no `NCard.qml`).
- **When NOT to reuse:** The outermost panel background (handled by `SmartPanel` and `PanelBackground`).

### `NCollapsible`
- **Path:** `Widgets/NCollapsible.qml`
- **Purpose:** Animated expandable container for secondary or advanced controls.
- **When to reuse:** Progressive disclosure of advanced options within settings.
- **When NOT to reuse:** When content must always remain visible.

### `NSettingsSection`
- **Path:** `Widgets/NSettingsSection.qml`
- **Purpose:** Open semantic subsection with colored icon, title, optional description and consistently aligned controls; no background, border, accordion or nested indentation.
- **When to reuse:** Grouping complete related controls within a major settings group. Its default content accepts visual controls and supporting nonvisual objects such as file pickers.

| Property | Type | Default | Purpose |
|---|---|---|---|
| `icon` | `string` | empty | Optional semantic artwork key. |
| `title` | `string` | empty | Wrapped subsection heading and accessible group name. |
| `description` | `string` | empty | Wrapped context below the heading. |
| `content` | default data alias | empty | Controls and supporting objects; existing handlers stay with their owner. |

### Settings examples
- **`NSettingsAppearancePreview`:** Bounded read-only illustration of scale, corners, surfaces and shadows. Replay is local and disabled when Style motion durations are zero. Only the illustration loader is visibility-gated; actual form editors remain loaded.
- **`NSettingsWallpaperPreview`:** Bounded read-only wallpaper framing illustration; `screen` supplies monitor geometry. Uses slot lookup rather than inheriting/creating a monitor wallpaper entry. Centering/tile size are illustrative at sample resolution. No transition engine or wallpaper action is instantiated.

### `NColorIcon`
- **Path:** `Widgets/NColorIcon.qml`; semantic catalog: `Commons/ColoredIcons.qml`.
- **API:** `icon` is a semantic key; `size` sets square implicit dimensions and defaults to `Style.baseWidgetSize * Style.uiScaleRatio`.
- **Purpose:** Filled Material Symbols Rounded artwork on an iRiS-style colored gradient tile. Bundled font; no INIR checkout, system-font installation or runtime download required.
- **When to reuse:** Settings categories and future category/folder panels (`folder-tools`, `folder-productivity`, `folder-creativity`, `folder-games` and related catalog keys).
- **When NOT to reuse:** Every action button, status indicator or system tray icon. Keep `NIcon` for monochrome actions and semantic state colors.
- **Fallback:** Unmapped keys use the actual existing Tabler symbol; a font-load failure is logged and also uses Tabler.
- **Artwork scope:** Fixed identity hues are icon assets, not Hydra UI color tokens. See `docs/UI_DESIGN.md` §2 and the bundled font attribution/license.

---

## 2. Interactive Buttons & Controls

### `NStateLayer`
- **Path:** `Widgets/NStateLayer.qml`; policy: `Commons/Style.qml`.
- **Purpose:** Shared background/focus painting, not a replacement activation control. Prefer the normal `N*` widget; use this for its background or an existing specialized interactive surface.
- **Inputs:** `baseColor` is the persistent surface; `stateColor` is its paired foreground; `hovering` and `pressed` are independent input states. `radius`, `color` and `border` expose the visual surface; `focusColor` is the preferred semantic stroke.
- **Focus:** `focusVisible` defaults to native `visualFocus`; `focusStrokeColor` is the readable computed stroke. The default policy is `Qt.NoFocus`; actual interactive owners opt into `Qt.StrongFocus`. Mouse activation does not impersonate keyboard focus.
- **Precedence:** Disabled suppresses transient painting; press wins over hover. Neither replaces selection, expansion or `hot`. Contrast-aware ink uses the same direction for hover/press, with Style motion gates and no layout animation.
- **Other geometry:** Per-corner `NBox` consumers use `Style.interactionColor` directly, keeping fused menus and custom corner contracts intact. Category icon artwork never supplies state colors.


### `NButton`
- **Path:** `Widgets/NButton.qml`
- **Purpose:** Standard text and icon button with hover animations, outlined mode, and keyboard focus states.
- **When to reuse:** Form submission, dialog action triggers, secondary operations.
- **When NOT to reuse:** Tiny circular icon triggers (use `NIconButton`) or binary toggles (use `NToggle`).
- **Anti-pattern to avoid:** Building custom clickable buttons with `Rectangle` and `MouseArea`.
- **Input/visual separation:** Keyboard focus belongs to the visual surface inside the focus scope; the existing pointer activation timing is unchanged. Filled actions retain their color/foreground pair on hover; outlined actions retain their outline.

### `NIconButton`
- **Path:** `Widgets/NIconButton.qml`
- **Purpose:** Compact icon button with tooltip support, hover feedback, custom radius, and UI scaling.
- **When to reuse:** Bar widget buttons, toolbar actions, card header action buttons, media controls.
- **When NOT to reuse:** Buttons that require a visible text label (use `NButton`).

### `NIconButtonHot`
- **Path:** `Widgets/NIconButtonHot.qml`
- **Purpose:** Stateful icon button with persistent `hot` status, pointer feedback and keyboard focus.
- **When to reuse:** Compact toggle/status actions in Control Center and equivalent panels. Hover and press do not erase `hot`; disabled controls do not paint a pressed state.

### `NToggle`
- **Path:** `Widgets/NToggle.qml`
- **Purpose:** Standard switch toggle with label, description, icon, keyboard focus, and modified value indicator.
- **When to reuse:** Boolean settings, feature enabling/disabling, service toggles.
- **When NOT to reuse:** Multi-option selection (use `NComboBox` or `NRadioButton`).

### `NValueSlider`
- **Path:** `Widgets/NValueSlider.qml`
- **Purpose:** Labelled numeric slider with reset-to-default indicator, value formatting, and keyboard stepping.
- **When to reuse:** Continuous numeric settings (volume, brightness, opacity, radius ratios).
- **When NOT to reuse:** Raw, unlabelled slider tracks (use `NSlider` if no label is needed).

### `NSlider`
- **Path:** `Widgets/NSlider.qml`
- **Purpose:** Minimal standalone slider track and thumb.
- **When to reuse:** Compact media scrubber bars or volume controls in tight bar widgets.

### `NComboBox` & `NSearchableComboBox`
- **Paths:** `Widgets/NComboBox.qml`, `Widgets/NSearchableComboBox.qml`
- **Purpose:** Dropdown select picker. `NSearchableComboBox` adds a search filter input.
- **When to reuse:** Selecting from a list of options (fonts, monitor connectors, schemes).
- **When NOT to reuse:** Simple 2-3 option binary/ternary choices (use chips or radio buttons).

### `NCheckbox` & `NRadioButton`
- **Paths:** `Widgets/NCheckbox.qml`, `Widgets/NRadioButton.qml`
- **Purpose:** Traditional checkbox and mutually exclusive radio button delegates.
- **When to reuse:** Multi-select lists, option lists within dialogs.

### `NSpinBox`
- **Path:** `Widgets/NSpinBox.qml`
- **Purpose:** Discrete numeric stepper with increment/decrement buttons.
- **When to reuse:** Integer inputs (timeouts, port numbers, pixel dimensions).

---

## 3. Typography & Text Presentation

### `NText`
- **Path:** `Widgets/NText.qml`
- **Purpose:** Standard text element with family configuration, scale factor, font size tokens, Markdown/RichText support, and auto-eliding.
- **When to reuse:** **All user-facing text** in Hydra.
- **When NOT to reuse:** Never substitute bare `Text` for `NText`.
- **Anti-pattern to avoid:** Using bare Qt `Text` or `TextEdit` without scaling and font family tokens.

### `NTextInput` & `NTextInputButton`
- **Paths:** `Widgets/NTextInput.qml`, `Widgets/NTextInputButton.qml`
- **Purpose:** Styled single-line text input field with placeholder, clear button, and focus ring. `NTextInputButton` includes an integrated action button.
- **When to reuse:** Search fields, settings text inputs, custom command fields.

### `NIcon`
- **Path:** `Widgets/NIcon.qml`
- **Purpose:** Unified icon renderer supporting Material Symbols, Freedesktop icon names, and SVG assets.
- **When to reuse:** All icons across buttons, labels, and indicators.

### `NLabel`
- **Path:** `Widgets/NLabel.qml`
- **Purpose:** Compound label containing icon, title, description, and change indicator badge.
- **When to reuse:** Standardized leading column in settings rows.

### `NHeader`
- **Path:** `Widgets/NHeader.qml`
- **Purpose:** Styled page and section header with title, subtitle, and optional close action.
- **When to reuse:** Top of panels and modal sheets.

### `NDivider`
- **Path:** `Widgets/NDivider.qml`
- **Purpose:** Subtle separator line using `HydraColor.mOutline`.
- **When to reuse:** Separating distinct content blocks when spacing alone is insufficient.

### `NScrollText`
- **Path:** `Widgets/NScrollText.qml`
- **Purpose:** Auto-scrolling horizontal text marquee for overflowing text.
- **When to reuse:** Media player track titles and dense status tickers.

---

## 4. Navigation & Views

### `NScrollView`
- **Path:** `Widgets/NScrollView.qml`
- **Purpose:** Styled flickable scroll container with Material-themed scrollbars and wheel handling.
- **When to reuse:** Vertical scrolling pages and lists.

### `NListView` & `NGridView`
- **Paths:** `Widgets/NListView.qml`, `Widgets/NGridView.qml`
- **Purpose:** Pre-styled Qt Quick list and grid views with proper spacing, margins, and scrollbars.
- **When to reuse:** Dynamic collections of cards, application icons, or wallpaper thumbnails.

### `NTabBar`, `NTabButton`, `NTabView`
- **Paths:** `Widgets/NTabBar.qml`, `Widgets/NTabButton.qml`, `Widgets/NTabView.qml`
- **Purpose:** Traditional horizontal tab bar and view container.
- **When to reuse:** Multi-tab interfaces where vertical scrolling is inappropriate.
- **Note:** In Settings, prefer `NSettingsGroupNav` and vertical scrolling over nested tab bars.

### `NTagFilter`
- **Path:** `Widgets/NTagFilter.qml`
- **Purpose:** Filter chip bar with multi-selection support.
- **When to reuse:** Filtering wallpaper catalogs, package lists, or icon pickers.

---

## 5. Menus & Popups

### `NContextMenu` & `NPopupContextMenu`
- **Paths:** `Widgets/NContextMenu.qml`, `Widgets/NPopupContextMenu.qml`
- **Purpose:** Right-click context menus with icons, shortcut labels, and submenus.
- **When to reuse:** Contextual actions on taskbar items, launcher entries, or desktop widgets.

---

## 6. Specialized Pickers

- `NColorPicker`, `NColorChoice`, `NColorSlider`, `NColorPickerDialog`: Color selection tools.
- `NKeybindRecorder`: Interactive keyboard shortcut recorder with modifier capture.
- `NFilePicker`: File and directory selection inputs.
- `NIconPicker`: Grid picker for system and symbol icons.
