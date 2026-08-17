import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

// Header of the wallpaper panel: title actions, view tabs, appearance and
// screen strips, and the unified search row. It owns no wallpaper state — it
// reports intent through properties and signals and lets the panel act.
NBox {
  id: root

  // Selected main view: 0 gallery, 1 grading, 2 palette.
  property int mainTabIndex: 0
  // Selected appearance slot: 0 light, 1 dark.
  property int appearanceTabIndex: 0
  // Selected screen tab.
  property int screenIndex: 0
  property bool screensStripVisible: false
  property bool devicesButtonVisible: false
  // Debounced local gallery filter; bound by the panel into the gallery views.
  property string localFilterText: ""

  property alias searchInput: searchInput

  signal closeRequested
  signal settingsRequested
  signal importRequested
  signal solidColorRequested
  signal wallhavenSettingsRequested(var anchorItem)
  // Emitted when the Wallhaven query changed and a search should run.
  signal wallhavenQueryChanged(string query)
  // Emitted when the down arrow should move focus into the results grid.
  signal focusGridRequested

  // Adopt a query set elsewhere (e.g. "find similar") without re-triggering
  // the debounce that would search for it a second time.
  function setSearchText(text) {
    searchInput.initializing = true;
    searchInput.text = text;
    Qt.callLater(() => searchInput.initializing = false);
  }

  function focusSearch() {
    if (searchInput.inputItem) {
      searchInput.inputItem.forceActiveFocus();
    }
  }

  color: Color.mSurfaceContainerLow
  radius: Style.radiusL
  implicitHeight: headerColumn.implicitHeight + Style.margin2L

  Timer {
    id: localFilterDebounce

    interval: 150
    onTriggered: root.localFilterText = searchInput.text
  }

  Timer {
    id: wallhavenQueryDebounce

    interval: 500
    onTriggered: {
      Settings.data.wallpaper.wallhavenQuery = searchInput.text;
      root.wallhavenQueryChanged(searchInput.text);
    }
  }

  ColumnLayout {
    id: headerColumn

    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIcon {
        icon: "settings-wallpaper-selector"
        pointSize: Style.fontSizeXXL
        color: Color.mPrimary
      }

      NText {
        text: I18n.tr("wallpaper.panel.title")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
      }

      NIconButton {
        visible: Settings.data.wallpaper.enabled
        icon: "dark-mode"
        tooltipText: Settings.data.wallpaper.linkLightAndDarkWallpapers ? I18n.tr("wallpaper.panel.header-separate-light-dark-tooltip") : I18n.tr("wallpaper.panel.header-link-light-dark-tooltip")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: !Settings.data.wallpaper.linkLightAndDarkWallpapers ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
        colorFg: !Settings.data.wallpaper.linkLightAndDarkWallpapers ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: Settings.data.wallpaper.linkLightAndDarkWallpapers = !Settings.data.wallpaper.linkLightAndDarkWallpapers
      }

      NIconButton {
        visible: Settings.data.wallpaper.enabled && root.devicesButtonVisible
        icon: "devices"
        tooltipText: Settings.data.wallpaper.setWallpaperOnAllMonitors ? I18n.tr("wallpaper.panel.header-devices-apply-all-tooltip") : I18n.tr("wallpaper.panel.header-devices-per-monitor-tooltip")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: !Settings.data.wallpaper.setWallpaperOnAllMonitors ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
        colorFg: !Settings.data.wallpaper.setWallpaperOnAllMonitors ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: Settings.data.wallpaper.setWallpaperOnAllMonitors = !Settings.data.wallpaper.setWallpaperOnAllMonitors
      }

      NIconButton {
        icon: "folder-open"
        tooltipText: I18n.tr("wallpaper.panel.import-local-tooltip")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mSecondaryContainer
        colorFg: Color.mOnSurfaceVariant
        colorFgHover: Color.mOnSecondaryContainer
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: root.importRequested()
      }

      NIconButton {
        icon: "palette"
        tooltipText: I18n.tr("wallpaper.panel.solid-color-tooltip")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: Settings.data.wallpaper.useSolidColor ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
        colorFg: Settings.data.wallpaper.useSolidColor ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: root.solidColorRequested()
      }

      NIconButton {
        icon: "settings"
        tooltipText: I18n.tr("panels.wallpaper.settings-title")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mSecondaryContainer
        colorFg: Color.mOnSurfaceVariant
        colorFgHover: Color.mOnSecondaryContainer
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: root.settingsRequested()
      }

      NIconButton {
        icon: "close"
        tooltipText: I18n.tr("common.close")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mSecondaryContainer
        colorFg: Color.mOnSurfaceVariant
        colorFgHover: Color.mOnSecondaryContainer
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: root.closeRequested()
      }
    }

    NDivider {
      Layout.fillWidth: true
      opacity: 0.35
    }

    NTabBar {
      id: mainViewTabBar

      Layout.fillWidth: true
      currentIndex: root.mainTabIndex
      spacing: Style.marginXS
      distributeEvenly: true

      onCurrentIndexChanged: {
        if (currentIndex >= 0) {
          root.mainTabIndex = currentIndex;
        }
      }

      NTabButton {
        text: I18n.tr("wallpaper.panel.tab-gallery")
        tabIndex: 0
        checked: mainViewTabBar.currentIndex === 0
      }
      NTabButton {
        text: I18n.tr("wallpaper.panel.tab-grading")
        tabIndex: 1
        checked: mainViewTabBar.currentIndex === 1
      }
      NTabButton {
        text: I18n.tr("wallpaper.panel.tab-palette")
        tabIndex: 2
        checked: mainViewTabBar.currentIndex === 2
      }
    }

    // Which slot new picks land in. Purely a selection target: it must not
    // flip the shell's own light/dark mode.
    NTabBar {
      id: appearanceTabBar

      visible: root.mainTabIndex === 0 && Settings.data.wallpaper.enabled && !Settings.data.wallpaper.linkLightAndDarkWallpapers
      Layout.fillWidth: true
      currentIndex: root.appearanceTabIndex
      spacing: Style.marginXS
      distributeEvenly: true

      onCurrentIndexChanged: {
        if (currentIndex >= 0) {
          root.appearanceTabIndex = currentIndex;
        }
      }

      NTabButton {
        text: I18n.tr("wallpaper.panel.appearance-light-tab")
        tabIndex: 0
        checked: appearanceTabBar.currentIndex === 0
      }
      NTabButton {
        text: I18n.tr("wallpaper.panel.appearance-dark-tab")
        tabIndex: 1
        checked: appearanceTabBar.currentIndex === 1
      }
    }

    NTabBar {
      id: screenTabBar

      visible: root.mainTabIndex === 0 && root.screensStripVisible
      Layout.fillWidth: true
      currentIndex: root.screenIndex
      spacing: Style.marginXS
      distributeEvenly: true

      onCurrentIndexChanged: {
        if (currentIndex >= 0) {
          root.screenIndex = currentIndex;
        }
      }

      Repeater {
        model: Quickshell.screens

        NTabButton {
          required property var modelData
          required property int index

          text: modelData.name || `Screen ${index + 1}`
          tabIndex: index
          checked: screenTabBar.currentIndex === index
        }
      }
    }

    // Unified search row: query, color extraction, scheme, source
    RowLayout {
      visible: root.mainTabIndex === 0
      Layout.fillWidth: true
      spacing: Style.marginM

      NTextInput {
        id: searchInput

        // Suppresses the debounced search while the text is set programmatically.
        property bool initializing: true

        inputIconName: "search"
        placeholderText: Settings.data.wallpaper.useWallhaven ? I18n.tr("placeholders.search-wallhaven") : I18n.tr("placeholders.search-wallpapers")
        fontSize: Style.fontSizeM
        Layout.fillWidth: true

        Component.onCompleted: {
          searchInput.text = Settings.data.wallpaper.useWallhaven ? (Settings.data.wallpaper.wallhavenQuery || "") : root.localFilterText;
          if (searchInput.inputItem && searchInput.inputItem.visible) {
            searchInput.inputItem.forceActiveFocus();
          }
          Qt.callLater(() => searchInput.initializing = false);
        }

        onTextChanged: {
          if (initializing) {
            return;
          }
          if (Settings.data.wallpaper.useWallhaven) {
            wallhavenQueryDebounce.restart();
          } else {
            localFilterDebounce.restart();
          }
        }

        onEditingFinished: {
          if (!Settings.data.wallpaper.useWallhaven) {
            return;
          }
          wallhavenQueryDebounce.stop();
          // Only search when the query really changed
          if (text !== WallhavenService.currentQuery) {
            Settings.data.wallpaper.wallhavenQuery = text;
            root.wallhavenQueryChanged(text);
          }
        }

        Keys.onPressed: event => {
                          if (Keybinds.checkKey(event, 'down', Settings)) {
                            root.focusGridRequested();
                            event.accepted = true;
                          }
                        }

        Connections {
          target: Settings.data.wallpaper

          function onUseWallhavenChanged() {
            root.setSearchText(Settings.data.wallpaper.useWallhaven ? (Settings.data.wallpaper.wallhavenQuery || "") : root.localFilterText);
          }
        }
      }

      NIconButton {
        icon: "color-swatch"
        tooltipText: Settings.data.colorSchemes.useWallpaperColors ? I18n.tr("wallpaper.panel.color-extraction-enabled") : I18n.tr("wallpaper.panel.color-extraction-disabled")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: Settings.data.colorSchemes.useWallpaperColors ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
        colorBgHover: Color.mSecondaryContainer
        colorFg: Settings.data.colorSchemes.useWallpaperColors ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
        colorFgHover: Color.mOnSecondaryContainer
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: {
          Settings.data.colorSchemes.useWallpaperColors = !Settings.data.colorSchemes.useWallpaperColors;
          if (Settings.data.colorSchemes.useWallpaperColors) {
            AppThemeService.generate();
          } else {
            ColorSchemeService.setPredefinedScheme(Settings.data.colorSchemes.predefinedScheme);
          }
        }
      }

      NComboBox {
        id: colorSchemeComboBox

        // Guards so the glow only plays for changes coming from elsewhere
        // (a favorite restoring its scheme), not from this combo itself.
        property bool _initialized: false
        property bool _userChanging: false

        Layout.fillWidth: false
        Layout.minimumWidth: 200 * Style.uiScaleRatio
        minimumWidth: 200 * Style.uiScaleRatio

        Component.onCompleted: Qt.callLater(() => {
                                              _initialized = true;
                                            })

        model: Settings.data.colorSchemes.useWallpaperColors ? TemplateProcessor.schemeTypes : ColorSchemeService.schemes.map(s => ({
                                                                                                                                      "key": ColorSchemeService.getBasename(s),
                                                                                                                                      "name": ColorSchemeService.getBasename(s)
                                                                                                                                    }))
        currentKey: Settings.data.colorSchemes.useWallpaperColors ? Settings.data.colorSchemes.generationMethod : Settings.data.colorSchemes.predefinedScheme

        onCurrentKeyChanged: {
          if (!_initialized) {
            return;
          }
          if (_userChanging) {
            _userChanging = false;
            return;
          }
          schemeGlowAnimation.restart();
        }

        onSelected: key => {
                      _userChanging = true;
                      if (Settings.data.colorSchemes.useWallpaperColors) {
                        Settings.data.colorSchemes.generationMethod = key;
                        AppThemeService.generate();
                      } else {
                        ColorSchemeService.setPredefinedScheme(key);
                      }
                      Qt.callLater(() => {
                                     _userChanging = false;
                                   });
                    }

        SequentialAnimation {
          id: schemeGlowAnimation

          NumberAnimation {
            target: colorSchemeComboBox
            property: "opacity"
            to: 0.3
            duration: Style.animationSlow
            easing.type: Easing.OutCubic
          }
          NumberAnimation {
            target: colorSchemeComboBox
            property: "opacity"
            to: 1.0
            duration: Style.animationSlow
            easing.type: Easing.InCubic
          }
        }
      }

      NComboBox {
        Layout.fillWidth: false

        model: [
          {
            "key": "local",
            "name": I18n.tr("common.local")
          },
          {
            "key": "wallhaven",
            "name": I18n.tr("wallpaper.panel.source-wallhaven")
          },
          {
            "key": "moewalls",
            "name": I18n.tr("wallpaper.panel.source-moewalls")
          },
          {
            "key": "motionbgs",
            "name": I18n.tr("wallpaper.panel.source-motionbgs")
          }
        ]
        currentKey: Settings.data.wallpaper.wallpaperSource || "local"
        onSelected: key => {
                      Settings.data.wallpaper.wallpaperSource = key;
                      Settings.data.wallpaper.useWallhaven = (key === "wallhaven");
                    }
      }

      NIconButton {
        id: wallhavenSettingsButton

        icon: "settings"
        tooltipText: I18n.tr("wallpaper.panel.wallhaven-settings-title")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mSecondaryContainer
        colorFg: Color.mOnSurfaceVariant
        colorFgHover: Color.mOnSecondaryContainer
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        visible: Settings.data.wallpaper.useWallhaven
        onClicked: {
          if (searchInput.inputItem) {
            searchInput.inputItem.focus = false;
          }
          root.wallhavenSettingsRequested(wallhavenSettingsButton);
        }
      }
    }

    WallhavenQuickFiltersBar {
      visible: Settings.data.wallpaper.useWallhaven && root.mainTabIndex === 0
      onSearchRequested: root.wallhavenQueryChanged(Settings.data.wallpaper.wallhavenQuery || "")
    }
  }
}
