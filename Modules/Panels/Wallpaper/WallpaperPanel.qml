import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.Settings
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets
import "./Components"

SmartPanel {
  id: root

  preferredWidth: 1100 * Style.uiScaleRatio
  preferredHeight: 700 * Style.uiScaleRatio
  preferredWidthRatio: 0.72
  preferredHeightRatio: 0.75
  panelBackgroundColor: Color.mSurface
  panelBorderColor: Qt.alpha(Color.mOutline, 0.30)

  // Positioning
  readonly property string screenBarPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property string panelPosition: {
    if (Settings.data.wallpaper.panelPosition === "follow_bar") {
      if (screenBarPosition === "left" || screenBarPosition === "right") {
        return `center_${screenBarPosition}`;
      } else {
        return `${screenBarPosition}_center`;
      }
    } else {
      return Settings.data.wallpaper.panelPosition;
    }
  }
  panelAnchorHorizontalCenter: panelPosition === "center" || panelPosition.endsWith("_center")
  panelAnchorVerticalCenter: panelPosition === "center"
  panelAnchorLeft: panelPosition !== "center" && panelPosition.endsWith("_left")
  panelAnchorRight: panelPosition !== "center" && panelPosition.endsWith("_right")
  panelAnchorBottom: panelPosition.startsWith("bottom_")
  panelAnchorTop: panelPosition.startsWith("top_")

  // Store direct reference to content for instant access
  property var contentItem: null

  onClosed: {
    if (contentItem?.wallhavenView?.previewOverlay) {
      contentItem.wallhavenView.previewOverlay.hide();
    }
  }

  // Override keyboard handlers to enable grid navigation
  function onDownPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView) {
      if (!view.gridView.hasActiveFocus) {
        view.gridView.forceActiveFocus();
        if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
          view.gridView.currentIndex = 0;
        }
      } else {
        if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
          view.gridView.currentIndex = 0;
        } else {
          view.gridView.moveCurrentIndexDown();
        }
      }
    }
  }

  function onUpPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.hasActiveFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexUp();
      }
    }
  }

  function onLeftPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.hasActiveFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexLeft();
      }
    }
  }

  function onRightPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.hasActiveFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexRight();
      }
    }
  }

  function onReturnPressed() {
    if (!contentItem)
      return;

    // Check if Wallhaven page input has focus
    if (contentItem.wallhavenView && contentItem.wallhavenView.visible && contentItem.wallhavenView.pageInput && contentItem.wallhavenView.pageInput.inputItem.activeFocus) {
      contentItem.wallhavenView.pageInput.submitPage();
      return;
    }

    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.hasActiveFocus) {
      let gridView = view.gridView;
      if (gridView.currentIndex >= 0 && gridView.currentIndex < gridView.model.count) {
        var item = gridView.model.get(gridView.currentIndex);
        view.selectItem(item.path, item.isDirectory);
      }
    }
  }

  function onEnterPressed() {
    onReturnPressed();
  }

  panelContent: Rectangle {
    id: panelContent

    property alias wallhavenView: wallhavenView
    property int currentScreenIndex: {
      if (screen !== null) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          if (Quickshell.screens[i].name == screen.name) {
            return i;
          }
        }
      }
      return 0;
    }
    property var currentScreen: Quickshell.screens[currentScreenIndex]
    property string filterText: ""
    property int appearanceTabIndex: 0
    property string activeSourceKey: Settings.data.wallpaper.useWallhaven ? "wallhaven" : "local"
    readonly property bool headerScreensStripAvailable: !Settings.data.wallpaper.setWallpaperOnAllMonitors || Settings.data.wallpaper.enableMultiMonitorDirectories
    readonly property bool headerDevicesButtonVisible: Quickshell.screens.length > 1 || Settings.data.wallpaper.enableMultiMonitorDirectories
    property alias screenRepeater: screenRepeater
    property string previewOverridePath: ""
    onCurrentScreenIndexChanged: {
      previewOverridePath = WallpaperService.getWallpaper(currentScreen?.name ?? "") || "";
    }
    readonly property string effectivePreviewWallpaperPath: {
      if (previewOverridePath !== "") {
        return previewOverridePath;
      }
      let view = screenRepeater ? screenRepeater.itemAt(currentScreenIndex) : null;
      if (view && view.currentWallpaper && view.currentWallpaper !== "") {
        return view.currentWallpaper;
      }
      return WallpaperService.getWallpaper(currentScreen?.name ?? "") || "";
    }

    Connections {
      target: WallpaperService
      function onWallpaperChanged(screenName, path) {
        if (!panelContent.currentScreen || screenName === panelContent.currentScreen.name || screenName === undefined || Settings.data.wallpaper.setWallpaperOnAllMonitors) {
          panelContent.previewOverridePath = path;
        }
      }
    }

    Component.onCompleted: {
      root.contentItem = panelContent;
    }

    // Function to update Wallhaven resolution filter
    function updateWallhavenResolution() {
      if (typeof WallhavenService === "undefined") {
        return;
      }
      WallhavenService.syncFromSettings();

      // Trigger new search with updated resolution
      if (Settings.data.wallpaper.useWallhaven) {
        if (wallhavenView) {
          wallhavenView.loading = true;
        }
        WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
      }
    }

    color: "transparent"

    // Wallhaven settings popup
    Loader {
      id: wallhavenSettingsPopup
      source: "WallhavenSettingsPopup.qml"
      onLoaded: {
        if (item) {
          item.screen = screen;
        }
      }
    }

    // Solid color picker dialog
    NColorPickerDialog {
      id: solidColorPicker
      screen: root.screen
      selectedColor: Settings.data.wallpaper.solidColor
      onColorSelected: color => WallpaperService.setSolidColor(color.toString())
    }

    // Local Wallpaper (Video & Image) File Picker
    NFilePicker {
      id: localWallpaperFilePicker
      title: "Selecionar Wallpaper Local (Vídeo Animado ou Imagem)"
      selectionMode: "files"
      initialPath: Settings.data.wallpaper.directory || Quickshell.env("HOME") + "/Pictures"
      nameFilters: ["Wallpapers Animados e Imagens (*.webm *.mp4 *.mkv *.mov *.png *.jpg *.jpeg *.webp)", "Todos os Arquivos (*)"]
      onAccepted: paths => {
        if (paths.length > 0) {
          var selPath = paths[0];
          var targetSc = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : currentScreen?.name;
          WallpaperService.changeWallpaper(selPath, targetSc, WallpaperService.wallpaperSelectionAppearance);
          WallpaperService.applyFavoriteTheme(selPath, targetSc, WallpaperService.wallpaperSelectionAppearance);
          ToastService.showNotice("Papel de Parede", "Wallpaper aplicado com sucesso!", "check", 3000);
        }
      }
    }

    // Focus management
    Connections {
      target: root
      function onOpened() {
        // Ensure contentItem is set
        if (!root.contentItem) {
          root.contentItem = panelContent;
        }
        // Reset grid view selections
        for (var i = 0; i < screenRepeater.count; i++) {
          let item = screenRepeater.itemAt(i);
          if (item && item.gridView) {
            item.gridView.currentIndex = -1;
          }
        }
        if (wallhavenView && wallhavenView.gridView) {
          wallhavenView.gridView.currentIndex = -1;
        }
        panelContent.appearanceTabIndex = Settings.data.colorSchemes.darkMode ? 1 : 0;
        WallpaperService.wallpaperSelectionAppearance = panelContent.appearanceTabIndex === 1 ? "dark" : "light";
        panelContent.previewOverridePath = WallpaperService.getWallpaper(panelContent.currentScreen?.name ?? "") || "";
        if (Settings.data.wallpaper.useWallhaven && wallhavenView && (!wallhavenView.initialized || wallhavenView.wallpapers.length === 0)) {
          Qt.callLater(() => wallhavenView.activate(false));
        }
        // Give initial focus to search input
        Qt.callLater(() => {
                       if (searchInput.inputItem) {
                         searchInput.inputItem.forceActiveFocus();
                       }
                     });
      }
    }

    // Debounce timer for search
    Timer {
      id: searchDebounceTimer
      interval: 150
      onTriggered: {
        panelContent.filterText = searchInput.text;
        // Trigger update on all screen views
        for (var i = 0; i < screenRepeater.count; i++) {
          let item = screenRepeater.itemAt(i);
          if (item && item.updateFiltered) {
            item.updateFiltered();
          }
        }
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      // LEFT COLUMN: Controls, Source Switcher, Tabs, and Main Grid/Adjuster/Palette (62% width)
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 62
        spacing: Style.marginM

        // Debounce timer for Wallhaven search
        Timer {
          id: wallhavenSearchDebounceTimer
          interval: 500
          onTriggered: {
            Settings.data.wallpaper.wallhavenQuery = searchInput.text;
            if (typeof WallhavenService !== "undefined") {
              wallhavenView.loading = true;
              WallhavenService.search(searchInput.text, 1);
            }
          }
        }

        // Header
        NBox {
          Layout.fillWidth: true
          Layout.preferredHeight: headerColumn.implicitHeight + Style.margin2L
          color: Color.mSurfaceContainerLow
          radius: Style.radiusL

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
                visible: Settings.data.wallpaper.enabled && panelContent.headerDevicesButtonVisible
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
                tooltipText: "Importar Wallpaper Local (Vídeo Animado ou Imagem)"
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: Color.mSurfaceContainerHigh
                colorBgHover: Color.mSecondaryContainer
                colorFg: Color.mOnSurfaceVariant
                colorFgHover: Color.mOnSecondaryContainer
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: localWallpaperFilePicker.open()
              }

              NIconButton {
                icon: "palette"
                tooltipText: I18n.tr("wallpaper.panel.solid-color-tooltip")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: Settings.data.wallpaper.useSolidColor ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
                colorFg: Settings.data.wallpaper.useSolidColor ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: solidColorPicker.open()
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
                onClicked: {
                  var settingsPanel = PanelService.getPanel("settingsPanel", screen);
                  settingsPanel.requestedTab = SettingsPanel.Tab.Wallpaper;
                  settingsPanel.open();
                }
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
                onClicked: root.close()
              }
            }

            NDivider {
              Layout.fillWidth: true
              opacity: 0.35
            }

            NTabBar {
              id: mainViewTabBar
              Layout.fillWidth: true
              currentIndex: 0
              spacing: Style.marginXS
              distributeEvenly: true

              NTabButton {
                text: "Galeria"
                tabIndex: 0
                checked: mainViewTabBar.currentIndex === 0
              }
              NTabButton {
                text: "Ajustes de Imagem"
                tabIndex: 1
                checked: mainViewTabBar.currentIndex === 1
              }
              NTabButton {
                text: "Paleta de Cores"
                tabIndex: 2
                checked: mainViewTabBar.currentIndex === 2
              }
            }

            NTabBar {
              id: appearanceTabBar
              visible: mainViewTabBar.currentIndex === 0 && Settings.data.wallpaper.enabled && !Settings.data.wallpaper.linkLightAndDarkWallpapers
              Layout.fillWidth: true
              currentIndex: panelContent.appearanceTabIndex
              spacing: Style.marginXS
              distributeEvenly: true

              onCurrentIndexChanged: {
                if (currentIndex < 0) {
                  return;
                }
                panelContent.appearanceTabIndex = currentIndex;
                WallpaperService.wallpaperSelectionAppearance = currentIndex === 1 ? "dark" : "light";
                Settings.data.colorSchemes.darkMode = currentIndex === 1;
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
              visible: mainViewTabBar.currentIndex === 0 && panelContent.headerScreensStripAvailable
              Layout.fillWidth: true
              currentIndex: currentScreenIndex
              onCurrentIndexChanged: currentScreenIndex = currentIndex
              spacing: Style.marginXS
              distributeEvenly: true

              Repeater {
                model: Quickshell.screens
                NTabButton {
                  required property var modelData
                  required property int index
                  text: modelData.name || `Screen ${index + 1}`
                  tabIndex: index
                  checked: {
                    screenTabBar.currentIndex === index;
                  }
                }
              }
            }

            // Unified search input and source
            RowLayout {
              visible: mainViewTabBar.currentIndex === 0
              Layout.fillWidth: true
              spacing: Style.marginM

              NTextInput {
                id: searchInput
                inputIconName: "search"
                placeholderText: Settings.data.wallpaper.useWallhaven ? I18n.tr("placeholders.search-wallhaven") : I18n.tr("placeholders.search-wallpapers")
                fontSize: Style.fontSizeM
                Layout.fillWidth: true

                property bool initializing: true
                Component.onCompleted: {
                  // Initialize text based on current mode
                  if (Settings.data.wallpaper.useWallhaven) {
                    searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                  } else {
                    searchInput.text = panelContent.filterText || "";
                  }
                  // Give focus to search input
                  if (searchInput.inputItem && searchInput.inputItem.visible) {
                    searchInput.inputItem.forceActiveFocus();
                  }
                  // Mark initialization as complete after a short delay
                  Qt.callLater(function () {
                    searchInput.initializing = false;
                  });
                }

                Connections {
                  target: Settings.data.wallpaper
                  function onUseWallhavenChanged() {
                    // Update text when mode changes
                    searchInput.initializing = true;
                    if (Settings.data.wallpaper.useWallhaven) {
                      searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                      Qt.callLater(() => wallhavenView.activate(false));
                    } else {
                      searchInput.text = panelContent.filterText || "";
                      wallhavenView.previewOverlay.hide();
                    }
                    Qt.callLater(() => searchInput.initializing = false);
                  }
                }

                onTextChanged: {
                  // Don't trigger search during initialization - Component.onCompleted will handle initial search
                  if (initializing) {
                    return;
                  }
                  if (Settings.data.wallpaper.useWallhaven) {
                    wallhavenSearchDebounceTimer.restart();
                  } else {
                    searchDebounceTimer.restart();
                  }
                }

                onEditingFinished: {
                  if (Settings.data.wallpaper.useWallhaven) {
                    wallhavenSearchDebounceTimer.stop();
                    // Only search if the query actually changed
                    if (typeof WallhavenService !== "undefined" && text !== WallhavenService.currentQuery) {
                      Settings.data.wallpaper.wallhavenQuery = text;
                      wallhavenView.loading = true;
                      WallhavenService.search(text, 1);
                    }
                  }
                }

                Keys.onPressed: event => {
                                  if (Keybinds.checkKey(event, 'down', Settings)) {
                                    if (Settings.data.wallpaper.useWallhaven) {
                                      if (wallhavenView && wallhavenView.gridView) {
                                        wallhavenView.gridView.forceActiveFocus();
                                      }
                                    } else {
                                      let currentView = screenRepeater.itemAt(currentScreenIndex);
                                      if (currentView && currentView.gridView) {
                                        currentView.gridView.forceActiveFocus();
                                      }
                                    }
                                    event.accepted = true;
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
                Layout.fillWidth: false
                Layout.minimumWidth: 200
                minimumWidth: 200

                property bool _initialized: false
                property bool _userChanging: false
                Component.onCompleted: Qt.callLater(() => {
                                                      _initialized = true;
                                                    })

                model: Settings.data.colorSchemes.useWallpaperColors ? TemplateProcessor.schemeTypes : ColorSchemeService.schemes.map(s => ({
                                                                                                                                              "key": ColorSchemeService.getBasename(s),
                                                                                                                                              "name": ColorSchemeService.getBasename(s)
                                                                                                                                            }))
                currentKey: Settings.data.colorSchemes.useWallpaperColors ? Settings.data.colorSchemes.generationMethod : Settings.data.colorSchemes.predefinedScheme
                onCurrentKeyChanged: {
                  if (!_initialized)
                    return;
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
                id: sourceComboBox
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
                currentKey: panelContent.activeSourceKey
                onSelected: key => {
                              panelContent.activeSourceKey = key;
                              Settings.data.wallpaper.useWallhaven = (key === "wallhaven");
                            }
              }

              // Settings button (only visible for Wallhaven)
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
                  if (wallhavenSettingsPopup.item) {
                    wallhavenSettingsPopup.item.showAt(wallhavenSettingsButton);
                  }
                }
              }
            }
              WallhavenQuickFiltersBar {
                visible: typeof WallhavenService !== "undefined" && Settings.data.wallpaper.useWallhaven && mainViewTabBar.currentIndex === 0
                onSearchRequested: {
                  wallhavenView.loading = true;
                  WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
                }
              }
          }
        }

        // Left Main Content (Grid / Grading / Palette)
        NBox {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceContainerLow
          radius: Style.radiusL

          StackLayout {
            id: contentStack
            anchors.fill: parent
            anchors.margins: Style.marginL

            currentIndex: {
              if (mainViewTabBar.currentIndex === 1)
                return 4;
              if (mainViewTabBar.currentIndex === 2)
                return 5;
              if (panelContent.activeSourceKey === "motionbgs")
                return 3;
              if (panelContent.activeSourceKey === "moewalls")
                return 2;
              if (Settings.data.wallpaper.useWallhaven)
                return 1;
              return 0;
            }

            // Local wallpapers (index 0)
            StackLayout {
              id: screenStack
              currentIndex: currentScreenIndex

              Repeater {
                id: screenRepeater
                model: Quickshell.screens
                delegate: WallpaperScreenView {
                  targetScreen: modelData
                }
              }
            }

            // Wallhaven wallpapers (index 1)
            WallhavenView {
              id: wallhavenView
            }

            // MoeWalls Live Video Wallpapers (index 2)
            MoeWallsView {
              id: moeWallsView
              screenName: currentScreen?.name ?? ""
            }

            // MotionBGS Live Video Wallpapers (index 3)
            MotionBgsView {
              id: motionBgsView
              screenName: currentScreen?.name ?? ""
            }

            // Wallpaper Grading & Filters (index 4)
            WallpaperGradingCard {
              id: wallpaperGradingCard
              wallpaperPath: panelContent.effectivePreviewWallpaperPath
              screenName: currentScreen?.name ?? ""
            }

            // Extracted Palette Sheet (index 5)
            WallpaperPaletteSheet {
              id: wallpaperPaletteSheet
              wallpaperPath: panelContent.effectivePreviewWallpaperPath
              screenName: currentScreen?.name ?? ""
            }
          }
        }
      }

      // RIGHT COLUMN: Pinned Live Desktop Preview Stack & Apply Card (38% width)
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 38
        color: Color.mSurfaceContainerLow
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true

            NIcon {
              icon: "device-desktop"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            NText {
              text: "Pré-visualização do Desktop"
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }
          }

          NDivider {
            Layout.fillWidth: true
            opacity: 0.35
          }

          MockDesktopPreview {
            id: mockDesktopPreview
            Layout.fillWidth: true
            Layout.fillHeight: true
            wallpaperPath: panelContent.effectivePreviewWallpaperPath
            screenName: currentScreen?.name ?? ""
            onApplyRequested: (path, fillMode) => {
              Settings.data.wallpaper.fillMode = fillMode;
              WallpaperService.changeWallpaper(path, currentScreen?.name, WallpaperService.wallpaperSelectionAppearance);
              AppThemeService.generate();
              ToastService.showNotice("Papel de Parede", "Papel de parede aplicado com sucesso!", "check", 3000);
            }
          }
        }
      }
    }
  }

  // Component for each screen's wallpaper view
  component WallpaperScreenView: Item {
    id: wallpaperScreenView
    property var targetScreen
    property alias gridView: wallpaperGridView

    // Local reactive state for this screen
    property list<string> wallpapersList: []
    property string currentWallpaper: ""
    property var filteredItems: [] // Combined list of { path, name, isDirectory }
    property var wallpapersWithNames: [] // Cached basenames for files
    property var directoriesList: [] // List of directories in browse mode

    // ListModel for the grid — enables animated reordering via move()
    ListModel {
      id: wallpaperModel
    }

    // Browse mode properties
    property string currentBrowsePath: WallpaperService.getCurrentBrowsePath(targetScreen?.name ?? "")
    property bool isBrowseMode: Settings.data.wallpaper.viewMode === "browse"
    property int _browseScanGeneration: 0

    // Favorited paths (any light/dark) first, then the rest
    function sortFavoritesToTop(items) {
      var favs = [];
      var rest = [];
      for (var i = 0; i < items.length; i++) {
        var it = items[i];
        if (!it.isDirectory && WallpaperService.isFavorite(it.path)) {
          favs.push(it);
        } else {
          rest.push(it);
        }
      }
      return favs.concat(rest);
    }

    // Rebuild filteredItems and sync to wallpaperModel (full replacement, no animation).
    // When skipSync is true the caller will animate the model itself.
    function updateFiltered(skipSync) {
      var combinedItems = [];

      // In browse mode, add directories first
      if (isBrowseMode) {
        for (var i = 0; i < directoriesList.length; i++) {
          var dirPath = directoriesList[i];
          combinedItems.push({
                               "path": dirPath,
                               "name": dirPath.split('/').pop(),
                               "isDirectory": true
                             });
        }
      }

      // Add files
      for (var i = 0; i < wallpapersList.length; i++) {
        combinedItems.push({
                             "path": wallpapersList[i],
                             "name": wallpapersList[i].split('/').pop(),
                             "isDirectory": false
                           });
      }

      combinedItems = sortFavoritesToTop(combinedItems);

      // Apply filter if text is present
      if (!panelContent.filterText || panelContent.filterText.trim().length === 0) {
        filteredItems = combinedItems;
        if (!skipSync)
          syncModel();
        return;
      }

      const results = FuzzySort.go(panelContent.filterText.trim(), combinedItems, {
                                     "key": 'name',
                                     "limit": 200
                                   });
      var filtered = results.map(function (r) {
        return r.obj;
      });
      filteredItems = sortFavoritesToTop(filtered);
      if (!skipSync)
        syncModel();
    }

    // Copy filteredItems into the ListModel (full rebuild, no animation).
    function syncModel() {
      wallpaperModel.clear();
      for (var i = 0; i < filteredItems.length; i++) {
        wallpaperModel.append(filteredItems[i]);
      }
      wallpaperGridView.currentIndex = -1;
      wallpaperGridView.positionViewAtBeginning();
    }

    // Animate a single item moving to its new position after a favorite toggle.
    function handleFavoriteMove(path) {
      // Find where the item currently sits in the model
      var fromIndex = -1;
      for (var i = 0; i < wallpaperModel.count; i++) {
        if (wallpaperModel.get(i).path === path) {
          fromIndex = i;
          break;
        }
      }
      if (fromIndex === -1)
        return;

      // Find where it should be in the freshly-computed filteredItems
      var toIndex = -1;
      for (var j = 0; j < filteredItems.length; j++) {
        if (filteredItems[j].path === path) {
          toIndex = j;
          break;
        }
      }
      if (toIndex === -1 || fromIndex === toIndex)
        return;

      wallpaperGridView.animateMovement = true;
      wallpaperModel.move(fromIndex, toIndex, 1);
      animateMovementResetTimer.restart();
    }

    // Turn off move animations shortly after the move completes so that
    // non-favorite model rebuilds (sort, filter, navigation) don't animate.
    Timer {
      id: animateMovementResetTimer
      readonly property int settleDelay: 50
      interval: Style.animationNormal + settleDelay
      onTriggered: {
        wallpaperGridView.animateMovement = false;
        reconcileModel();
      }
    }

    // Reorder wallpaperModel to match filteredItems using in-place moves.
    // Avoids clear+rebuild which would destroy delegates and flash thumbnails.
    function reconcileModel() {
      for (var i = 0; i < filteredItems.length; i++) {
        var currentPos = -1;
        for (var j = i; j < wallpaperModel.count; j++) {
          if (wallpaperModel.get(j).path === filteredItems[i].path) {
            currentPos = j;
            break;
          }
        }
        if (currentPos !== -1 && currentPos !== i) {
          wallpaperModel.move(currentPos, i, 1);
        }
      }
    }

    Component.onCompleted: {
      refreshWallpaperScreenData();
    }

    Connections {
      target: WallpaperService
      function onWallpaperChanged(screenName, path) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          currentWallpaper = WallpaperService.getWallpaperPathForSlot(targetScreen.name, WallpaperService.wallpaperSelectionAppearance);
        }
      }
      function onWallpaperSelectionAppearanceChanged() {
        if (targetScreen !== null) {
          currentWallpaper = WallpaperService.getWallpaperPathForSlot(targetScreen.name, WallpaperService.wallpaperSelectionAppearance);
          updateFiltered(false);
        }
      }
      function onWallpaperDirectoryChanged(screenName, directory) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          // Reset browse path when root directory changes
          if (isBrowseMode) {
            WallpaperService.navigateToRoot(targetScreen.name);
          }
          refreshWallpaperScreenData();
        }
      }
      function onWallpaperListChanged(screenName, count) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          refreshWallpaperScreenData();
        }
      }
      function onBrowsePathChanged(screenName, path) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          currentBrowsePath = path;
          refreshWallpaperScreenData();
        }
      }
      function onFavoritesChanged(path) {
        updateFiltered(true);   // recompute filteredItems but skip full model rebuild
        handleFavoriteMove(path); // animate the item to its new position
      }
    }

    function refreshWallpaperScreenData() {
      if (targetScreen === null) {
        return;
      }

      currentWallpaper = WallpaperService.getWallpaperPathForSlot(targetScreen.name, WallpaperService.wallpaperSelectionAppearance);

      if (isBrowseMode) {
        // In browse mode, scan current directory for both files and directories
        var browsePath = WallpaperService.getCurrentBrowsePath(targetScreen.name);
        currentBrowsePath = browsePath;

        // Bump generation so stale scan callbacks from rapid navigation are ignored
        var gen = ++_browseScanGeneration;
        WallpaperService.scanDirectoryWithDirs(targetScreen.name, browsePath, function (result) {
          if (gen !== _browseScanGeneration)
            return; // Stale callback from a superseded navigation
          wallpapersList = result.files;
          directoriesList = result.directories;
          Logger.d("WallpaperPanel", "Browse mode: Got", wallpapersList.length, "files and", directoriesList.length, "directories for screen", targetScreen.name);
          updateFiltered();
        });
      } else {
        // Normal mode: just use the wallpaper list from service
        wallpapersList = WallpaperService.getWallpapersList(targetScreen.name);
        directoriesList = [];
        Logger.d("WallpaperPanel", "Got", wallpapersList.length, "wallpapers for screen", targetScreen.name);
        updateFiltered();
      }
    }

    function selectItem(path, isDirectory) {
      if (isDirectory) {
        WallpaperService.setBrowsePath(targetScreen.name, path);
      } else {
        var screen = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : targetScreen.name;
        WallpaperService.changeWallpaper(path, screen, WallpaperService.wallpaperSelectionAppearance);
        WallpaperService.applyFavoriteTheme(path, screen, WallpaperService.wallpaperSelectionAppearance);
      }
    }

    // Helper function to cycle view modes
    function cycleViewMode() {
      var mode = Settings.data.wallpaper.viewMode;
      if (mode === "single") {
        Settings.data.wallpaper.viewMode = "recursive";
      } else if (mode === "recursive") {
        Settings.data.wallpaper.viewMode = "browse";
      } else {
        Settings.data.wallpaper.viewMode = "single";
      }
    }

    // Helper function to get icon for current view mode
    function getViewModeIcon() {
      var mode = Settings.data.wallpaper.viewMode;
      if (mode === "single")
        return "folder";
      if (mode === "recursive")
        return "folders";
      return "folder-open";
    }

    // Helper function to get tooltip for current view mode
    function getViewModeTooltip() {
      var mode = Settings.data.wallpaper.viewMode;
      var modeName;
      if (mode === "single")
        modeName = I18n.tr("panels.wallpaper.view-mode-single");
      else if (mode === "recursive")
        modeName = I18n.tr("panels.wallpaper.view-mode-recursive");
      else
        modeName = I18n.tr("panels.wallpaper.view-mode-browse");
      return I18n.tr("panels.wallpaper.view-mode-cycle-tooltip").replace("{mode}", modeName);
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      // Combined toolbar: navigation (left) + actions (right)
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        // Left side: navigation (back, home, path)
        NIconButton {
          icon: "arrow-left"
          tooltipText: I18n.tr("wallpaper.browse.go-up")
          enabled: isBrowseMode && currentBrowsePath !== WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
          onClicked: WallpaperService.navigateUp(targetScreen?.name ?? "")
          baseSize: Style.baseWidgetSize * 0.8
        }

        NIconButton {
          icon: "home"
          tooltipText: I18n.tr("wallpaper.browse.go-root")
          enabled: isBrowseMode && currentBrowsePath !== WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
          onClicked: WallpaperService.navigateToRoot(targetScreen?.name ?? "")
          baseSize: Style.baseWidgetSize * 0.8
        }

        NScrollText {
          text: isBrowseMode ? currentBrowsePath : WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
          Layout.fillWidth: true
          scrollMode: NScrollText.ScrollMode.Hover
          fadeCornerRadius: Style.radiusM

          NText {
            text: isBrowseMode ? currentBrowsePath : WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }

        // Right side: actions (view mode, hide filenames, refresh)
        NIconButton {
          property string sortOrder: Settings.data.wallpaper.sortOrder || "name"
          icon: {
            if (sortOrder === "date_desc")
              return "clock";
            if (sortOrder === "date_asc")
              return "history";
            if (sortOrder === "name_desc")
              return "sort-descending";
            if (sortOrder === "random")
              return "arrows-shuffle";
            return "sort-ascending";
          }
          tooltipText: {
            if (sortOrder === "date_desc")
              return I18n.tr("wallpaper.panel.sort-date-desc");
            if (sortOrder === "date_asc")
              return I18n.tr("wallpaper.panel.sort-date-asc");
            if (sortOrder === "name_desc")
              return I18n.tr("wallpaper.panel.sort-name-desc");
            if (sortOrder === "random")
              return I18n.tr("wallpaper.panel.sort-random");
            return I18n.tr("wallpaper.panel.sort-name-asc");
          }
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: {
            var next = "name";
            if (sortOrder === "name")
              next = "date_desc";
            else if (sortOrder === "date_desc")
              next = "name"; // Toggle simpler: Name -> Newest -> Name
            // Expanded cycle: Name -> Newest -> Oldest -> Z-A -> Random -> Name
            // User just asked for "newest first", so let's make it easy to reach.
            // Let's do: Name (A-Z) -> Newest -> Oldest -> Name (Z-A) -> ...

            if (sortOrder === "name")
              next = "date_desc";
            else if (sortOrder === "date_desc")
              next = "date_asc";
            else if (sortOrder === "date_asc")
              next = "name_desc";
            else if (sortOrder === "name_desc")
              next = "random";
            else
              next = "name";

            Settings.data.wallpaper.sortOrder = next;
          }
        }

        NIconButton {
          icon: getViewModeIcon()
          tooltipText: getViewModeTooltip()
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: cycleViewMode()
        }

        NIconButton {
          icon: Settings.data.wallpaper.hideWallpaperFilenames ? "id-off" : "id"
          tooltipText: Settings.data.wallpaper.hideWallpaperFilenames ? I18n.tr("panels.wallpaper.settings-hide-wallpaper-filenames-tooltip-show") : I18n.tr("panels.wallpaper.settings-hide-wallpaper-filenames-tooltip-hide")
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: Settings.data.wallpaper.hideWallpaperFilenames = !Settings.data.wallpaper.hideWallpaperFilenames
        }

        NIconButton {
          icon: Settings.data.wallpaper.showHiddenFiles ? "eye" : "eye-closed"
          tooltipText: Settings.data.wallpaper.showHiddenFiles ? I18n.tr("panels.wallpaper.settings-show-hidden-files-tooltip-hide") : I18n.tr("panels.wallpaper.settings-show-hidden-files-tooltip-show")
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: Settings.data.wallpaper.showHiddenFiles = !Settings.data.wallpaper.showHiddenFiles
        }

        NIconButton {
          icon: "refresh"
          tooltipText: I18n.tr("tooltips.refresh-wallpaper-list")
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: {
            if (isBrowseMode) {
              refreshWallpaperScreenData();
            } else {
              WallpaperService.refreshWallpapersList();
            }
          }
        }
      }

      NGridView {
        id: wallpaperGridView

        Layout.fillWidth: true
        Layout.fillHeight: true

        visible: !WallpaperService.scanning
        interactive: true
        keyNavigationEnabled: true
        keyNavigationWraps: false
        highlightFollowsCurrentItem: false
        currentIndex: -1

        model: wallpaperModel

        Component.onCompleted: {
          positionViewAtBeginning();
        }

        property int columns: (screen.width > 1920) ? 5 : 4
        property int itemSize: cellWidth

        cellWidth: Math.floor((availableWidth - leftMargin - rightMargin) / columns)
        cellHeight: Math.floor(itemSize * 0.7) + Style.marginXS + Style.fontSizeXS + Style.marginM

        leftMargin: Style.marginS
        rightMargin: Style.marginS
        topMargin: Style.marginS
        bottomMargin: Style.marginS

        onCurrentIndexChanged: {
          if (currentIndex >= 0) {
            positionViewAtIndex(currentIndex, GridView.Contain);
          }
        }

        onKeyPressed: event => {
                        if (Keybinds.checkKey(event, 'enter', Settings)) {
                          if (currentIndex >= 0 && currentIndex < filteredItems.length) {
                            selectItem(filteredItems[currentIndex]);
                          }
                          event.accepted = true;
                        }
                      }

        delegate: Item {
          id: wallpaperItemWrapper
          width: wallpaperGridView.cellWidth
          height: wallpaperGridView.cellHeight
          Accessible.role: Accessible.ListItem
          Accessible.name: wallpaperItem.filename
          Accessible.selected: wallpaperItem.isSelected || wallpaperGridView.currentIndex === index

          ColumnLayout {
            id: wallpaperItem
            anchors.fill: parent
            anchors.margins: Style.marginXS

            property string wallpaperPath: model.path ?? ""
            property bool isDirectory: model.isDirectory ?? false
            property bool isSelected: !isDirectory && (wallpaperPath === currentWallpaper)
            property bool isFavorited: {
              WallpaperService.favoritesRevision;
              return !isDirectory && WallpaperService.isFavorite(wallpaperPath);
            }
            property string filename: model.name ?? wallpaperPath.split('/').pop()
            property string cachedPath: ""

            spacing: Style.marginXS

            Component.onCompleted: {
              if (!isDirectory && ImageCacheService.initialized) {
                ImageCacheService.getThumbnail(wallpaperPath, function (path, success) {
                  if (wallpaperItem)
                    wallpaperItem.cachedPath = success ? path : wallpaperPath;
                });
              } else if (!isDirectory) {
                cachedPath = wallpaperPath;
              }
            }

            Item {
              id: imageContainer
              Layout.fillWidth: true
              Layout.fillHeight: true

              property real imageHeight: Math.round(wallpaperGridView.itemSize * 0.67)

              // Directory display
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: imageContainer.imageHeight
                color: Color.mSurfaceContainerHigh
                radius: Style.radiusL
                visible: wallpaperItem.isDirectory
                border.color: wallpaperGridView.currentIndex === index ? Color.mPrimary : "transparent"
                border.width: wallpaperGridView.currentIndex === index ? Style.borderL : 0

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: Style.marginS

                  NIcon {
                    icon: "folder"
                    pointSize: Style.fontSizeXXXL
                    color: Color.mPrimary
                    Layout.alignment: Qt.AlignHCenter
                  }
                }
              }

              // Image display (for non-directories)
              NImageRounded {
                id: img
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: imageContainer.imageHeight
                visible: !wallpaperItem.isDirectory
                imagePath: wallpaperItem.cachedPath
                radius: Style.radiusL
                borderColor: {
                  if (wallpaperItem.isSelected) {
                    return Color.mPrimary;
                  }
                  if (wallpaperGridView.currentIndex === index) {
                    return Color.mPrimary;
                  }
                  return "transparent";
                }
                borderWidth: (wallpaperItem.isSelected || wallpaperGridView.currentIndex === index) ? Style.borderL : 0
                imageFillMode: Image.PreserveAspectCrop
              }

              // Loading/error state background (for non-directories)
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: imageContainer.imageHeight
                color: Color.mSurfaceContainerHigh
                radius: Style.radiusL
                visible: !wallpaperItem.isDirectory && (img.status === Image.Loading || img.status === Image.Error || wallpaperItem.cachedPath === "")

                NIcon {
                  icon: "image"
                  pointSize: Style.fontSizeL
                  color: Color.mOnSurfaceVariant
                  anchors.centerIn: parent
                }
              }

              NBusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (imageContainer.imageHeight - height) / 2
                visible: !wallpaperItem.isDirectory && (img.status === Image.Loading || wallpaperItem.cachedPath === "")
                running: visible
                size: 18
              }

              Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Style.marginS
                width: 28
                height: 28
                radius: width / 2
                z: 6
                color: Color.mPrimaryContainer
                border.color: "transparent"
                border.width: 0
                visible: wallpaperItem.isSelected

                NIcon {
                  icon: "check"
                  pointSize: Style.fontSizeM
                  color: Color.mOnPrimaryContainer
                  anchors.centerIn: parent
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: {}
                }
              }

              // Favorite star button (top-left)
              Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Style.marginS
                width: 28
                height: 28
                radius: width / 2
                visible: !wallpaperItem.isDirectory && (wallpaperItem.isFavorited || hoverHandler.hovered || wallpaperGridView.currentIndex === index)
                color: {
                  if (wallpaperItem.isFavorited)
                    return starHoverHandler.hovered ? Color.mPrimaryContainer : Color.mSecondaryContainer;
                  return starHoverHandler.hovered ? Color.mSurfaceContainerHighest : Color.mSurfaceContainerHigh;
                }
                opacity: wallpaperItem.isFavorited || starHoverHandler.hovered ? 1.0 : 0.7
                z: 11

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }
                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                  }
                }

                NIcon {
                  icon: wallpaperItem.isFavorited ? "star-filled" : "star"
                  pointSize: Style.fontSizeM
                  color: {
                    if (wallpaperItem.isFavorited)
                      return starHoverHandler.hovered ? Color.mOnPrimaryContainer : Color.mOnSecondaryContainer;
                    return starHoverHandler.hovered ? Color.mOnSurface : Color.mOnSurfaceVariant;
                  }
                  anchors.centerIn: parent
                }

                HoverHandler {
                  id: starHoverHandler
                }

                TapHandler {
                  onTapped: {
                    var mon = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : (wallpaperScreenView.targetScreen ? wallpaperScreenView.targetScreen.name : undefined);
                    WallpaperService.toggleFavorite(wallpaperItem.wallpaperPath, WallpaperService.wallpaperSelectionAppearance, mon);
                  }
                }
              }

              // Palette color dots (bottom-center, favorites only) — taps must not fall through to selectItem
              Item {
                id: paletteRow
                anchors.bottom: img.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Style.marginS
                z: 10
                implicitWidth: paletteRowRow.implicitWidth
                implicitHeight: paletteRowRow.implicitHeight
                width: implicitWidth
                height: implicitHeight
                visible: wallpaperItem.isFavorited && paletteRow.colors.length > 0

                property int diameter: 25 * Style.uiScaleRatio
                property int _favRevision: 0
                property var favData: {
                  _favRevision;
                  WallpaperService.favoritesRevision;
                  Settings.data.wallpaper.linkLightAndDarkWallpapers;
                  return WallpaperService.getFavoriteForDisplay(wallpaperItem.wallpaperPath);
                }
                property var colors: favData && favData.paletteColors ? favData.paletteColors : []
                property bool isDark: {
                  if (!favData) {
                    return false;
                  }
                  if (favData.appearance === "dark") {
                    return true;
                  }
                  if (favData.appearance === "light") {
                    return false;
                  }
                  return favData.darkMode === true;
                }

                Connections {
                  target: WallpaperService
                  function onFavoriteDataUpdated(path) {
                    if (path === wallpaperItem.wallpaperPath)
                      paletteRow._favRevision++;
                  }
                }

                Row {
                  id: paletteRowRow
                  spacing: Style.marginXS

                  // Sun/moon only when light/dark share one wallpaper (which appearance the favorite targets)
                  Rectangle {
                    width: paletteRow.diameter
                    height: paletteRow.diameter
                    radius: width * 0.5
                    visible: Settings.data.wallpaper.linkLightAndDarkWallpapers
                    color: Color.mSurface
                    border.color: Color.mShadow
                    border.width: Style.borderS

                    NIcon {
                      icon: paletteRow.isDark ? "moon" : "sun"
                      pointSize: parent.width * 0.45
                      color: Color.mOnSurface
                      anchors.centerIn: parent
                    }
                  }

                  Repeater {
                    model: paletteRow.colors

                    Rectangle {
                      width: paletteRow.diameter
                      height: paletteRow.diameter
                      radius: width * 0.5
                      color: modelData
                      border.color: Color.mShadow
                      border.width: Style.borderS
                    }
                  }
                }

                TapHandler {
                  onTapped: {}
                }
              }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: imageContainer.imageHeight
                color: Color.mSurface
                radius: Style.radiusL
                opacity: (hoverHandler.hovered || wallpaperItem.isSelected || wallpaperGridView.currentIndex === index) ? 0 : 0.18
                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                  }
                }
              }

              HoverHandler {
                id: hoverHandler
              }

              TapHandler {
                onTapped: {
                  wallpaperGridView.forceActiveFocus();
                  wallpaperGridView.currentIndex = index;
                  selectItem(wallpaperItem.wallpaperPath, wallpaperItem.isDirectory);
                }
              }
            }

            NText {
              text: wallpaperItem.filename
              visible: !Settings.data.wallpaper.hideWallpaperFilenames
              color: (hoverHandler.hovered || wallpaperItem.isSelected || wallpaperGridView.currentIndex === index) ? Color.mOnSurface : Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              Layout.fillWidth: true
              Layout.leftMargin: Style.marginS
              Layout.rightMargin: Style.marginS
              Layout.alignment: Qt.AlignHCenter
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
          }
        }
      }

      // Empty / scanning state
      Rectangle {
        color: Color.mSurfaceContainerLow
        radius: Style.radiusL
        border.color: "transparent"
        border.width: 0
        visible: (wallpaperModel.count === 0 && !WallpaperService.scanning) || WallpaperService.scanning
        Layout.fillWidth: true
        Layout.preferredHeight: 130

        ColumnLayout {
          anchors.fill: parent
          visible: WallpaperService.scanning
          NBusyIndicator {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
          }
        }

        ColumnLayout {
          anchors.fill: parent
          visible: wallpaperModel.count === 0 && !WallpaperService.scanning
          Item {
            Layout.fillHeight: true
          }
          NIcon {
            icon: "folder-open"
            pointSize: Style.fontSizeXXL
            color: Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: (panelContent.filterText && panelContent.filterText.length > 0) ? I18n.tr("wallpaper.no-match") : (isBrowseMode ? I18n.tr("wallpaper.browse.empty-directory") : I18n.tr("wallpaper.no-wallpaper"))
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: (panelContent.filterText && panelContent.filterText.length > 0) ? I18n.tr("wallpaper.try-different-search") : (isBrowseMode ? I18n.tr("wallpaper.browse.go-up-hint") : I18n.tr("wallpaper.configure-directory"))
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.alignment: Qt.AlignHCenter
          }
          Item {
            Layout.fillHeight: true
          }
        }
      }
    }
  }

  // Component for Wallhaven wallpapers view
  component WallhavenView: Item {
    id: wallhavenViewRoot
    property alias gridView: wallhavenGridView
    property alias pageInput: pageInput
    property alias previewOverlay: previewOverlayItem

    property var wallpapers: []
    property bool loading: false
    property string errorMessage: ""
    property bool initialized: false

    Connections {
      target: typeof WallhavenService !== "undefined" ? WallhavenService : null
      function onSearchCompleted(results, meta) {
        wallhavenViewRoot.wallpapers = results || [];
        wallhavenViewRoot.loading = false;
        wallhavenViewRoot.errorMessage = "";
      }
      function onSearchFailed(error) {
        wallhavenViewRoot.loading = false;
        wallhavenViewRoot.errorMessage = error || "";
      }
    }

    Component.onCompleted: {
      if (Settings.data.wallpaper.useWallhaven) {
        activate(false);
      }
    }

    function activate(forceRefresh) {
      if (typeof WallhavenService === "undefined") {
        return;
      }
      initialized = true;
      loading = true;
      errorMessage = "";
      WallhavenService.syncFromSettings();
      const query = Settings.data.wallpaper.wallhavenQuery || "";
      const page = WallhavenService.currentQuery === query ? WallhavenService.currentPage : 1;
      WallhavenService.search(query, page, forceRefresh === true);
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        NGridView {
          id: wallhavenGridView

          anchors.fill: parent

          visible: !loading && errorMessage === "" && (wallpapers && wallpapers.length > 0)
          interactive: true
          keyNavigationEnabled: true
          keyNavigationWraps: false
          highlightFollowsCurrentItem: false
          currentIndex: -1

          model: wallpapers || []

          onModelChanged: {
            // Reset selection and scroll position when model changes
            currentIndex = -1;
            positionViewAtBeginning();
          }

          Component.onCompleted: {
            positionViewAtBeginning();
          }

          property int columns: Math.max(2, Math.min(6, Math.floor(availableWidth / (190 * Style.uiScaleRatio))))
          property int itemSize: cellWidth

          cellWidth: Math.floor((availableWidth - leftMargin - rightMargin) / columns)
          cellHeight: Math.floor(itemSize * 0.7) + Style.marginXS + Style.fontSizeXS + Style.marginM

          leftMargin: Style.marginS
          rightMargin: Style.marginS
          topMargin: Style.marginS
          bottomMargin: Style.marginS

          onCurrentIndexChanged: {
            if (currentIndex >= 0) {
              positionViewAtIndex(currentIndex, GridView.Contain);
            }
          }

          onKeyPressed: event => {
                          if (Keybinds.checkKey(event, 'enter', Settings)) {
                            if (currentIndex >= 0 && currentIndex < wallpapers.length) {
                              let wallpaper = wallpapers[currentIndex];
                              wallhavenDownloadAndApply(wallpaper);
                            }
                            event.accepted = true;
                          }
                        }

          delegate: Item {
            id: wallhavenItemWrapper
            width: wallhavenGridView.cellWidth
            height: wallhavenGridView.cellHeight
            Accessible.role: Accessible.ListItem
            Accessible.name: wallhavenItem.wallpaperId
            Accessible.selected: wallhavenGridView.currentIndex === index

              ColumnLayout {
                id: wallhavenItem
                anchors.fill: parent
                anchors.margins: Style.marginXS

                property string thumbnailUrl: (modelData && typeof WallhavenService !== "undefined") ? WallhavenService.getThumbnailUrl(modelData, "large") : ""
                property string wallpaperId: (modelData && modelData.id) ? modelData.id : ""
                readonly property bool downloading: typeof WallhavenService !== "undefined" && WallhavenService.isDownloading(wallpaperId)

              spacing: Style.marginXS

              Item {
                id: imageContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                property real imageHeight: Math.round(wallhavenGridView.itemSize * 0.67)

                NImageRounded {
                  id: img
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: imageContainer.imageHeight
                  imagePath: wallhavenItem.thumbnailUrl
                  radius: Style.radiusL
                  borderColor: {
                    if (wallhavenGridView.currentIndex === index) {
                      return Color.mPrimary;
                    }
                    return "transparent";
                  }
                  borderWidth: wallhavenGridView.currentIndex === index ? Style.borderL : 0
                  imageFillMode: Image.PreserveAspectCrop
                }

                // Loading/error state background
                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: imageContainer.imageHeight
                  color: Color.mSurfaceContainerHigh
                  radius: Style.radiusL
                  visible: img.status === Image.Loading || img.status === Image.Error || wallhavenItem.thumbnailUrl === ""

                  NIcon {
                    icon: "image"
                    pointSize: Style.fontSizeL
                    color: Color.mOnSurfaceVariant
                    anchors.centerIn: parent
                  }
                }

                NBusyIndicator {
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: (imageContainer.imageHeight - height) / 2
                  visible: img.status === Image.Loading || wallhavenItem.downloading
                  running: visible
                  size: 18
                  z: 12
                }

                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: imageContainer.imageHeight
                  color: Color.mSurface
                  radius: Style.radiusL
                  opacity: (hoverHandler.hovered || wallhavenGridView.currentIndex === index) ? 0 : 0.18
                  Behavior on opacity {
                    NumberAnimation {
                      duration: Style.animationFast
                    }
                  }
                }

                HoverHandler {
                  id: hoverHandler
                }

                Timer {
                  id: previewTimer
                  interval: 800
                  // Don't let hover on other cells re-trigger while the overlay is
                  // already open — the cursor crosses neighboring cells on its way
                  // to the overlay's Apply button, and their hover shouldn't hijack it.
                  running: hoverHandler.hovered && !(wallhavenViewRoot.previewOverlay && wallhavenViewRoot.previewOverlay.visible)
                  onTriggered: {
                    if (wallhavenViewRoot.previewOverlay) {
                      wallhavenViewRoot.previewOverlay.show(modelData);
                    }
                  }
                }

                TapHandler {
                  enabled: !wallhavenItem.downloading
                  onTapped: {
                    wallhavenGridView.forceActiveFocus();
                    wallhavenGridView.currentIndex = index;
                    wallhavenDownloadAndApply(modelData);
                  }
                }
              }

              NText {
                text: wallhavenItem.wallpaperId || I18n.tr("common.unknown")
                visible: !Settings.data.wallpaper.hideWallpaperFilenames
                color: (hoverHandler.hovered || wallhavenGridView.currentIndex === index) ? Color.mOnSurface : Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginS
                Layout.rightMargin: Style.marginS
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }
          }
        }

        // Loading overlay - fills same space as GridView to prevent jumping
        Rectangle {
          anchors.fill: parent
          color: Color.mSurfaceContainerLow
          radius: Style.radiusL
          border.color: "transparent"
          border.width: 0
          visible: loading || (typeof WallhavenService !== "undefined" && WallhavenService.fetching)
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NBusyIndicator {
              size: Style.baseWidgetSize * 1.5
              color: Color.mPrimary
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: WallhavenService.retrySeconds > 0
                ? I18n.tr("wallpaper.wallhaven.retrying", { seconds: WallhavenService.retrySeconds })
                : I18n.tr("wallpaper.wallhaven.loading")
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeM
              Layout.alignment: Qt.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }

        // Error overlay
        Rectangle {
          anchors.fill: parent
          color: Color.mSurfaceContainerLow
          radius: Style.radiusL
          border.color: "transparent"
          border.width: 0
          visible: errorMessage !== "" && !loading
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "alert-circle"
              pointSize: Style.fontSizeXXL
              color: Color.mError
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: errorMessage
              color: Color.mOnSurface
              wrapMode: Text.WordWrap
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            NButton {
              text: I18n.tr("common.retry")
              icon: "refresh"
              Layout.alignment: Qt.AlignHCenter
              onClicked: wallhavenViewRoot.activate(true)
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }

        // Empty state overlay
        Rectangle {
          anchors.fill: parent
          color: Color.mSurfaceContainerLow
          radius: Style.radiusL
          border.color: "transparent"
          border.width: 0
          visible: (!wallpapers || wallpapers.length === 0) && !loading && errorMessage === ""
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "image"
              pointSize: Style.fontSizeXXL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: I18n.tr("wallpaper.wallhaven.no-results")
              color: Color.mOnSurface
              wrapMode: Text.WordWrap
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      // Pagination
      RowLayout {
        Layout.fillWidth: true
        visible: errorMessage === "" && typeof WallhavenService !== "undefined"
        spacing: Style.marginS

        Item {
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "chevron-left"
          colorBg: Color.mSurfaceContainerHigh
          colorBgHover: Color.mSecondaryContainer
          colorFg: Color.mOnSurfaceVariant
          colorFgHover: Color.mOnSecondaryContainer
          colorBorder: "transparent"
          colorBorderHover: "transparent"
          enabled: !loading && WallhavenService.currentPage > 1 && !WallhavenService.fetching
          onClicked: WallhavenService.previousPage()
        }

        RowLayout {
          spacing: Style.marginXS

          NText {
            text: I18n.tr("wallpaper.wallhaven.page-prefix")
            color: Color.mOnSurface
          }

          NTextInput {
            id: pageInput
            text: "" + WallhavenService.currentPage
            Layout.preferredWidth: 50 * Style.uiScaleRatio
            Layout.maximumWidth: 50 * Style.uiScaleRatio
            Layout.fillWidth: false
            minimumInputWidth: 50 * Style.uiScaleRatio
            horizontalAlignment: Text.AlignHCenter
            inputMethodHints: Qt.ImhDigitsOnly
            enabled: !loading && !WallhavenService.fetching
            showClearButton: false

            Connections {
              target: WallhavenService
              function onCurrentPageChanged() {
                pageInput.text = "" + WallhavenService.currentPage;
              }
            }

            function submitPage() {
              var page = parseInt(text);
              if (!isNaN(page) && page >= 1 && page <= WallhavenService.lastPage) {
                if (page !== WallhavenService.currentPage) {
                  WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", page);
                }
              } else {
                // Reset to current page if invalid
                text = "" + WallhavenService.currentPage;
              }
              // Force focus loss to ensure UI updates cleanly
              pageInput.inputItem.focus = false;
            }

            onEditingFinished: submitPage()
          }

          NText {
            text: I18n.tr("wallpaper.wallhaven.page-suffix").replace("{total}", WallhavenService.lastPage)
            color: Color.mOnSurface
          }
        }

          NIconButton {
            icon: "chevron-right"
          colorBg: Color.mSurfaceContainerHigh
          colorBgHover: Color.mSecondaryContainer
          colorFg: Color.mOnSurfaceVariant
          colorFgHover: Color.mOnSecondaryContainer
          colorBorder: "transparent"
          colorBorderHover: "transparent"
          enabled: WallhavenService.currentPage < WallhavenService.lastPage && !WallhavenService.fetching
            onClicked: WallhavenService.nextPage()
          }

          NIconButton {
            icon: "refresh"
            tooltipText: I18n.tr("tooltips.refresh-wallhaven")
            colorBg: Color.mSurfaceContainerHigh
            colorBgHover: Color.mSecondaryContainer
            colorFg: Color.mOnSurfaceVariant
            colorFgHover: Color.mOnSecondaryContainer
            colorBorder: "transparent"
            colorBorderHover: "transparent"
            enabled: !WallhavenService.fetching
            onClicked: wallhavenViewRoot.activate(true)
          }

        Item {
          Layout.fillWidth: true
        }
      }
    }

    // -------------------------------
    function wallhavenDownloadAndApply(wallpaper, targetScreen) {
      if (typeof WallhavenService !== "undefined") {
        const applyToAll = Settings.data.wallpaper.setWallpaperOnAllMonitors;
        const selectedScreen = currentScreenIndex >= 0 && currentScreenIndex < Quickshell.screens.length
          ? Quickshell.screens[currentScreenIndex]
          : null;
        const explicitScreenName = typeof targetScreen === "string" ? targetScreen : targetScreen?.name;
        const screenName = applyToAll ? undefined : (explicitScreenName || selectedScreen?.name);
        const appearance = WallpaperService.wallpaperSelectionAppearance;
        WallhavenService.downloadWallpaper(wallpaper, function (success, localPath) {
          if (success) {
            WallpaperService.changeWallpaper(localPath, screenName, appearance);
            WallpaperService.applyFavoriteTheme(localPath, screenName, appearance);
          } else {
            ToastService.showError("Wallhaven", I18n.tr("wallpaper.wallhaven.download-failed"));
          }
        });
      }
    }

    WallhavenPreviewOverlay {
      id: previewOverlayItem
      onFindSimilarRequested: id => {
        if (typeof WallhavenService !== "undefined") {
          Settings.data.wallpaper.wallhavenQuery = "like:" + id;
          if (searchInput) searchInput.text = "like:" + id;
          wallhavenViewRoot.loading = true;
          WallhavenService.search("like:" + id, 1);
        }
      }
      onApplyRequested: wallpaper => {
        wallhavenDownloadAndApply(wallpaper);
      }
    }
  }
}
