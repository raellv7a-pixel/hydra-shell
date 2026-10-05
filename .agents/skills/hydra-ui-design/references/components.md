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

### `NSettingsGroupNav`
- **Path:** `Widgets/NSettingsGroupNav.qml`
- **Purpose:** Horizontal jump chip navigation for quickly scrolling to sections within a settings page.
- **When to reuse:** At the top of settings pages with multiple collapsible cards.
- **When NOT to reuse:** Traditional tab navigation or single-topic dialogs.

### `NBox`
- **Path:** `Widgets/NBox.qml`
- **Purpose:** Base rounded group container elevated above its parent panel (`Color.mSurfaceContainerHigh`), supporting per-corner radius overrides.
- **When to reuse:** Wrapping related controls, form rows, or card strips within panels and settings. This is Hydra's **primary card primitive** (there is no `NCard.qml`).
- **When NOT to reuse:** The outermost panel background (handled by `SmartPanel` and `PanelBackground`).

### `NCollapsible`
- **Path:** `Widgets/NCollapsible.qml`
- **Purpose:** Animated expandable container for secondary or advanced controls.
- **When to reuse:** Progressive disclosure of advanced options within settings.
- **When NOT to reuse:** When content must always remain visible.

### `NSettingsSection`
- **Path:** `Widgets/NSettingsSection.qml`
- **Purpose:** Semantic settings section divider with title and optional action button.
- **When to reuse:** Grouping multiple related `NBox` cards or fields under a clear heading.

---

## 2. Interactive Buttons & Controls

### `NButton`
- **Path:** `Widgets/NButton.qml`
- **Purpose:** Standard text and icon button with hover animations, outlined mode, and keyboard focus states.
- **When to reuse:** Form submission, dialog action triggers, secondary operations.
- **When NOT to reuse:** Tiny circular icon triggers (use `NIconButton`) or binary toggles (use `NToggle`).
- **Anti-pattern to avoid:** Building custom clickable buttons with `Rectangle` and `MouseArea`.

### `NIconButton`
- **Path:** `Widgets/NIconButton.qml`
- **Purpose:** Compact icon button with tooltip support, hover feedback, custom radius, and UI scaling.
- **When to reuse:** Bar widget buttons, toolbar actions, card header action buttons, media controls.
- **When NOT to reuse:** Buttons that require a visible text label (use `NButton`).

### `NIconButtonHot`
- **Path:** `Widgets/NIconButtonHot.qml`
- **Purpose:** Specialized icon button with instant hover hit detection and hotkey indicator.
- **When to reuse:** High-traffic toolbar and dock controls requiring hotkey hints.

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
- **Purpose:** Subtle separator line using `Color.mOutline`.
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
