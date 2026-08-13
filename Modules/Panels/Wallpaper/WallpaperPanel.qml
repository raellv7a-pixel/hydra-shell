import QtQuick
import QtQuick.Layouts
import Quickshell
import "./Components"
import "./Views"
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.Settings
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

// Shell of the wallpaper panel: window placement, keyboard routing and the
// composition of header, source views and the live desktop preview. All the
// per-view behaviour lives in ./Views, all the reusable chrome in ./Components.
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
      }
      return `${screenBarPosition}_center`;
    }
    return Settings.data.wallpaper.panelPosition;
  }
  panelAnchorHorizontalCenter: panelPosition === "center" || panelPosition.endsWith("_center")
  panelAnchorVerticalCenter: panelPosition === "center"
  panelAnchorLeft: panelPosition !== "center" && panelPosition.endsWith("_left")
  panelAnchorRight: panelPosition !== "center" && panelPosition.endsWith("_right")
  panelAnchorBottom: panelPosition.startsWith("bottom_")
  panelAnchorTop: panelPosition.startsWith("top_")

  // Direct reference to the content root for instant access
  property var contentItem: null

  // -------------------------------------------------------------------
  // Keyboard routing — every view exposes `gridView` and activateCurrentIndex()
  // -------------------------------------------------------------------
  function _activeGrid() {
    return contentItem?.activeGridOwner()?.gridView ?? null;
  }

  function _moveGridSelection(step) {
    const grid = _activeGrid();
    if (!grid || grid.count === 0) {
      return;
    }
    if (!grid.hasActiveFocus) {
      grid.forceActiveFocus();
    }
    if (grid.currentIndex < 0) {
      grid.currentIndex = 0;
      return;
    }
    step(grid);
  }

  function onDownPressed() {
    _moveGridSelection(grid => grid.moveCurrentIndexDown());
  }

  function onUpPressed() {
    const grid = _activeGrid();
    if (grid?.hasActiveFocus) {
      _moveGridSelection(g => g.moveCurrentIndexUp());
    }
  }

  function onLeftPressed() {
    const grid = _activeGrid();
    if (grid?.hasActiveFocus) {
      _moveGridSelection(g => g.moveCurrentIndexLeft());
    }
  }

  function onRightPressed() {
    const grid = _activeGrid();
    if (grid?.hasActiveFocus) {
      _moveGridSelection(g => g.moveCurrentIndexRight());
    }
  }

  function onReturnPressed() {
    if (!contentItem) {
      return;
    }

    const wallhaven = contentItem.wallhavenView;
    if (wallhaven?.visible && wallhaven.pageInput?.inputItem?.activeFocus) {
      wallhaven.pageInput.submitPage();
      return;
    }

    const owner = contentItem.activeGridOwner();
    if (owner?.gridView?.hasActiveFocus) {
      owner.activateCurrentIndex();
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
        for (let i = 0; i < Quickshell.screens.length; i++) {
          if (Quickshell.screens[i].name === screen.name) {
            return i;
          }
        }
      }
      return 0;
    }
    readonly property var currentScreen: Quickshell.screens[currentScreenIndex]
    readonly property string currentScreenName: currentScreen?.name ?? ""
    // Screen the pick applies to: undefined means "every monitor".
    readonly property var applyTargetScreenName: Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : currentScreenName

    readonly property string sourceKey: Settings.data.wallpaper.wallpaperSource || "local"
    readonly property bool headerScreensStripAvailable: !Settings.data.wallpaper.setWallpaperOnAllMonitors || Settings.data.wallpaper.enableMultiMonitorDirectories
    readonly property bool headerDevicesButtonVisible: Quickshell.screens.length > 1 || Settings.data.wallpaper.enableMultiMonitorDirectories

    // Wallpaper currently applied to this screen, shown by the preview column
    // whenever nothing is being considered.
    property string appliedWallpaperPath: ""

    // Wallpaper the user is considering — set by whichever view owns the grid
    // cursor, cleared when the context changes (screen, source, tab), so the
    // preview column always says what it is showing.
    property var previewCandidate: null

    // Path the grading/palette tabs work on: the candidate when there is one.
    readonly property string effectivePreviewWallpaperPath: {
      if (previewCandidate && previewCandidate.source === "local" && previewCandidate.path) {
        return previewCandidate.path;
      }
      if (appliedWallpaperPath !== "") {
        return appliedWallpaperPath;
      }
      return WallpaperService.getWallpaper(currentScreenName) || "";
    }

    // The view owning the grid that keyboard navigation should drive; the
    // live-video providers bring their own navigation, hence null.
    function activeGridOwner() {
      if (header.mainTabIndex !== 0) {
        return null;
      }
      if (sourceKey === "wallhaven") {
        return wallhavenView;
      }
      if (sourceKey === "local") {
        return screenRepeater.itemAt(currentScreenIndex);
      }
      return null;
    }

    // The view backing the active source, whatever kind of navigation it has.
    function activeSourceView() {
      switch (sourceKey) {
      case "wallhaven":
        return wallhavenView;
      case "moewalls":
        return moeWallsView;
      case "motionbgs":
        return motionBgsView;
      default:
        return screenRepeater.itemAt(currentScreenIndex);
      }
    }

    function applyWallpaper(path) {
      const target = applyTargetScreenName;
      const appearance = WallpaperService.wallpaperSelectionAppearance;
      WallpaperService.changeWallpaper(path, target, appearance);
      WallpaperService.applyFavoriteTheme(path, target, appearance);
    }

    // Commits the previewed wallpaper through its provider, so each source
    // keeps its own flow (local resolution probe, Wallhaven download, video
    // download) instead of the pane knowing about any of them.
    function applyCandidate() {
      if (!previewCandidate) {
        return;
      }
      switch (previewCandidate.source) {
      case "wallhaven":
        wallhavenView.downloadAndApply(previewCandidate.data);
        return;
      case "video":
        activeSourceView()?.downloadAndApply(previewCandidate.data);
        return;
      default:
        screenRepeater.itemAt(currentScreenIndex)?.selectItem(previewCandidate.path, false);
      }
    }

    color: "transparent"

    onCurrentScreenIndexChanged: {
      appliedWallpaperPath = WallpaperService.getWallpaper(currentScreenName) || "";
      previewCandidate = null;
    }

    // Switching source or leaving the gallery tab drops the candidate: it
    // belongs to a grid that is no longer on screen.
    onSourceKeyChanged: previewCandidate = null

    Component.onCompleted: {
      root.contentItem = panelContent;
      // Migration: the source used to be inferred from useWallhaven alone.
      if (Settings.data.wallpaper.useWallhaven && sourceKey === "local") {
        Settings.data.wallpaper.wallpaperSource = "wallhaven";
      }
    }

    Connections {
      target: WallpaperService

      function onWallpaperChanged(screenName, path) {
        if (!panelContent.currentScreen || screenName === panelContent.currentScreenName || screenName === undefined || Settings.data.wallpaper.setWallpaperOnAllMonitors) {
          panelContent.appliedWallpaperPath = path;
        }
      }
    }

    Connections {
      target: root

      function onOpened() {
        if (!root.contentItem) {
          root.contentItem = panelContent;
        }

        // Clear stale keyboard cursors
        for (let i = 0; i < screenRepeater.count; i++) {
          const item = screenRepeater.itemAt(i);
          if (item?.gridView) {
            item.gridView.currentIndex = -1;
          }
        }
        wallhavenView.gridView.currentIndex = -1;

        // Start on the slot matching the shell's current mode, without
        // touching that mode from here on.
        header.appearanceTabIndex = Settings.data.colorSchemes.darkMode ? 1 : 0;
        panelContent.appliedWallpaperPath = WallpaperService.getWallpaper(panelContent.currentScreenName) || "";
        panelContent.previewCandidate = null;

        if (Settings.data.wallpaper.useWallhaven && (!wallhavenView.initialized || wallhavenView.wallpapers.length === 0)) {
          Qt.callLater(() => wallhavenView.activate(false));
        }
        Qt.callLater(() => header.focusSearch());
      }
    }

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

    NColorPickerDialog {
      id: solidColorPicker

      screen: root.screen
      selectedColor: Settings.data.wallpaper.solidColor
      onColorSelected: color => WallpaperService.setSolidColor(color.toString())
    }

    // Local import of an image or animated wallpaper
    NFilePicker {
      id: localWallpaperFilePicker

      title: I18n.tr("wallpaper.panel.import-local-title")
      selectionMode: "files"
      initialPath: Settings.data.wallpaper.directory || Quickshell.env("HOME") + "/Pictures"
      nameFilters: [I18n.tr("wallpaper.panel.import-filter-media") + " (*.webm *.mp4 *.mkv *.mov *.png *.jpg *.jpeg *.webp)", I18n.tr("wallpaper.panel.import-filter-all") + " (*)"]
      onAccepted: paths => {
        if (paths.length === 0) {
          return;
        }
        panelContent.applyWallpaper(paths[0]);
        ToastService.showNotice(I18n.tr("wallpaper.panel.applied-toast-title"), I18n.tr("wallpaper.panel.applied-toast-body"), "check", 3000);
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      // LEFT COLUMN: header + active source view (roughly 62% of the width)
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: root.width * 0.62
        Layout.minimumWidth: 380 * Style.uiScaleRatio
        spacing: Style.marginM

        WallpaperPanelHeader {
          id: header

          Layout.fillWidth: true

          screenIndex: panelContent.currentScreenIndex
          screensStripVisible: panelContent.headerScreensStripAvailable
          devicesButtonVisible: panelContent.headerDevicesButtonVisible

          onScreenIndexChanged: panelContent.currentScreenIndex = screenIndex
          // Selecting the light/dark tab only retargets the wallpaper slot;
          // the shell's own light/dark mode is deliberately left alone.
          onAppearanceTabIndexChanged: WallpaperService.wallpaperSelectionAppearance = appearanceTabIndex === 1 ? "dark" : "light"

          onCloseRequested: root.close()
          onImportRequested: localWallpaperFilePicker.open()
          onSolidColorRequested: solidColorPicker.open()
          onSettingsRequested: {
            const settingsPanel = PanelService.getPanel("settingsPanel", screen);
            settingsPanel.requestedTab = SettingsPanel.Tab.Wallpaper;
            settingsPanel.open();
          }
          onWallhavenSettingsRequested: anchorItem => {
            if (wallhavenSettingsPopup.item) {
              wallhavenSettingsPopup.item.showAt(anchorItem);
            }
          }
          onWallhavenQueryChanged: query => wallhavenView.search(query)
          onFocusGridRequested: {
            // Only hand focus over when the grid can actually take it —
            // otherwise focus lands nowhere and every shortcut goes dead.
            const owner = panelContent.activeGridOwner();
            if (owner?.gridView && owner.gridView.count > 0) {
              owner.gridView.forceActiveFocus();
            }
          }
        }

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
              if (header.mainTabIndex === 1) {
                return 4;
              }
              if (header.mainTabIndex === 2) {
                return 5;
              }
              switch (panelContent.sourceKey) {
              case "motionbgs":
                return 3;
              case "moewalls":
                return 2;
              case "wallhaven":
                return 1;
              default:
                return 0;
              }
            }

            // Local gallery, one view per screen (index 0)
            StackLayout {
              currentIndex: panelContent.currentScreenIndex

              Repeater {
                id: screenRepeater

                model: Quickshell.screens

                delegate: WallpaperLocalGallery {
                  required property var modelData

                  targetScreen: modelData
                  filterText: header.localFilterText
                  upscalePrompt: upscalePromptItem
                  // Only the visible screen's gallery may drive the preview.
                  onPreviewRequested: candidate => {
                    if (modelData?.name === panelContent.currentScreenName) {
                      panelContent.previewCandidate = candidate;
                    }
                  }
                }
              }
            }

            // Wallhaven (index 1)
            WallhavenView {
              id: wallhavenView

              screenIndex: panelContent.currentScreenIndex
              upscalePrompt: upscalePromptItem
              onSearchQueryRequested: query => header.setSearchText(query)
              onPreviewRequested: candidate => panelContent.previewCandidate = candidate
            }

            // MoeWalls live video wallpapers (index 2)
            MoeWallsView {
              id: moeWallsView

              screenName: panelContent.applyTargetScreenName ?? ""
              onPreviewRequested: candidate => panelContent.previewCandidate = candidate
            }

            // MotionBGS live video wallpapers (index 3)
            MotionBgsView {
              id: motionBgsView

              screenName: panelContent.applyTargetScreenName ?? ""
              onPreviewRequested: candidate => panelContent.previewCandidate = candidate
            }

            // Image grading (index 4)
            WallpaperGradingCard {
              wallpaperPath: panelContent.effectivePreviewWallpaperPath
              screenName: panelContent.currentScreenName
            }

            // Extracted palette (index 5)
            WallpaperPaletteSheet {
              screen: root.screen
              wallpaperPath: panelContent.effectivePreviewWallpaperPath
              screenName: panelContent.currentScreenName
            }
          }
        }
      }

      // RIGHT COLUMN: preview of the wallpaper under consideration, its
      // metadata and the actions that commit it (~42% of the width)
      WallpaperPreviewPane {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: root.width * 0.42
        Layout.minimumWidth: 300 * Style.uiScaleRatio

        candidate: panelContent.previewCandidate
        appliedWallpaperPath: panelContent.appliedWallpaperPath
        screenName: panelContent.currentScreenName
        applying: {
          const candidate = panelContent.previewCandidate;
          if (!candidate) {
            return false;
          }
          if (candidate.source === "wallhaven") {
            return WallhavenService.isDownloading(candidate.data?.id ?? "");
          }
          if (candidate.source === "video") {
            return panelContent.activeSourceView()?.applyingVideoId === String(candidate.data?.id ?? "");
          }
          return false;
        }

        onApplyRequested: panelContent.applyCandidate()
        onFindSimilarRequested: wallpaperId => wallhavenView.findSimilar(wallpaperId)
      }
    }

    // Low-resolution warning + waifu2x upscale, shared by the local gallery
    // and the Wallhaven apply flow — anchored to the whole panel so it
    // dominates regardless of which tab triggered it.
    WallpaperUpscalePrompt {
      id: upscalePromptItem
    }
  }
}
