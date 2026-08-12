import QtQuick
import QtQuick.Layouts
import "../Components"
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Local wallpaper gallery for a single screen: directory toolbar, filtered
// grid and the apply flow (including the low-resolution prompt).
Item {
  id: root

  // Screen this gallery manages (ShellScreen).
  property var targetScreen
  // Search text owned by the panel header.
  property string filterText: ""
  // Shared low-resolution warning modal, provided by the panel.
  property Item upscalePrompt: null

  property alias gridView: wallpaperGridView

  // Wallpaper currently applied to targetScreen for the active light/dark slot.
  property string currentWallpaper: ""

  property list<string> wallpapersList: []
  property var directoriesList: []
  // Combined and filtered { path, name, isDirectory } records backing the model.
  property var filteredItems: []

  // Wallpaper the side preview should show: whatever the grid cursor is on.
  // Directories have nothing to preview.
  readonly property var currentCandidate: {
    const index = wallpaperGridView.currentIndex;
    if (index < 0 || index >= wallpaperModel.count) {
      return null;
    }
    const item = wallpaperModel.get(index);
    if (!item || item.isDirectory) {
      return null;
    }
    return {
      "source": "local",
      "path": item.path,
      "title": item.name,
      "data": item.path,
      "meta": {}
    };
  }

  // Emitted whenever the cursor lands on a different wallpaper.
  signal previewRequested(var candidate)

  onCurrentCandidateChanged: previewRequested(currentCandidate)

  property string currentBrowsePath: WallpaperService.getCurrentBrowsePath(targetScreen?.name ?? "")
  readonly property bool isBrowseMode: Settings.data.wallpaper.viewMode === "browse"
  readonly property string rootDirectory: WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
  property int _browseScanGeneration: 0

  onFilterTextChanged: updateFiltered(false)

  // ListModel (rather than a plain array) so favorite toggles can animate a
  // single item to its new position with move() instead of a full rebuild.
  ListModel {
    id: wallpaperModel
  }

  Component.onCompleted: refreshWallpaperScreenData()

  Connections {
    target: WallpaperService

    function onWallpaperChanged(screenName, path) {
      if (root.targetScreen && screenName === root.targetScreen.name) {
        root.currentWallpaper = WallpaperService.getWallpaperPathForSlot(screenName, WallpaperService.wallpaperSelectionAppearance);
      }
    }

    function onWallpaperSelectionAppearanceChanged() {
      if (!root.targetScreen) {
        return;
      }
      root.currentWallpaper = WallpaperService.getWallpaperPathForSlot(root.targetScreen.name, WallpaperService.wallpaperSelectionAppearance);
      root.updateFiltered(false);
    }

    function onWallpaperDirectoryChanged(screenName, directory) {
      if (!root.targetScreen || screenName !== root.targetScreen.name) {
        return;
      }
      if (root.isBrowseMode) {
        WallpaperService.navigateToRoot(screenName);
      }
      root.refreshWallpaperScreenData();
    }

    function onWallpaperListChanged(screenName, count) {
      if (root.targetScreen && screenName === root.targetScreen.name) {
        root.refreshWallpaperScreenData();
      }
    }

    function onBrowsePathChanged(screenName, path) {
      if (root.targetScreen && screenName === root.targetScreen.name) {
        root.currentBrowsePath = path;
        root.refreshWallpaperScreenData();
      }
    }

    function onFavoritesChanged(path) {
      root.updateFiltered(true); // recompute order, keep the delegates alive
      root.handleFavoriteMove(path); // animate the item to its new slot
    }
  }

  // -------------------------------------------------------------------
  // Model plumbing
  // -------------------------------------------------------------------
  function refreshWallpaperScreenData() {
    if (!targetScreen) {
      return;
    }

    currentWallpaper = WallpaperService.getWallpaperPathForSlot(targetScreen.name, WallpaperService.wallpaperSelectionAppearance);

    if (!isBrowseMode) {
      wallpapersList = WallpaperService.getWallpapersList(targetScreen.name);
      directoriesList = [];
      updateFiltered(false);
      return;
    }

    const browsePath = WallpaperService.getCurrentBrowsePath(targetScreen.name);
    currentBrowsePath = browsePath;

    // Bump the generation so callbacks from superseded navigations are dropped.
    const generation = ++_browseScanGeneration;
    WallpaperService.scanDirectoryWithDirs(targetScreen.name, browsePath, function (result) {
      if (generation !== root._browseScanGeneration) {
        return;
      }
      root.wallpapersList = result.files;
      root.directoriesList = result.directories;
      root.updateFiltered(false);
    });
  }

  // Favorited paths (either appearance slot) float to the top.
  function sortFavoritesToTop(items) {
    const favorites = [];
    const rest = [];
    for (let i = 0; i < items.length; i++) {
      if (!items[i].isDirectory && WallpaperService.isFavorite(items[i].path)) {
        favorites.push(items[i]);
      } else {
        rest.push(items[i]);
      }
    }
    return favorites.concat(rest);
  }

  // Rebuild filteredItems; with skipSync the caller animates the model itself.
  function updateFiltered(skipSync) {
    let combined = [];

    if (isBrowseMode) {
      for (let i = 0; i < directoriesList.length; i++) {
        combined.push({
                        "path": directoriesList[i],
                        "name": directoriesList[i].split('/').pop(),
                        "isDirectory": true
                      });
      }
    }

    for (let j = 0; j < wallpapersList.length; j++) {
      combined.push({
                      "path": wallpapersList[j],
                      "name": wallpapersList[j].split('/').pop(),
                      "isDirectory": false
                    });
    }

    const query = (filterText || "").trim();
    if (query.length > 0) {
      const results = FuzzySort.go(query, combined, {
                                     "key": 'name',
                                     "limit": 200
                                   });
      combined = results.map(r => r.obj);
    }

    filteredItems = sortFavoritesToTop(combined);
    if (!skipSync) {
      syncModel();
    }
  }

  function syncModel() {
    wallpaperModel.clear();
    for (let i = 0; i < filteredItems.length; i++) {
      wallpaperModel.append(filteredItems[i]);
    }
    wallpaperGridView.currentIndex = -1;
    wallpaperGridView.positionViewAtBeginning();
  }

  // Animate a single item to its new position after a favorite toggle.
  function handleFavoriteMove(path) {
    let fromIndex = -1;
    for (let i = 0; i < wallpaperModel.count; i++) {
      if (wallpaperModel.get(i).path === path) {
        fromIndex = i;
        break;
      }
    }
    if (fromIndex === -1) {
      return;
    }

    let toIndex = -1;
    for (let j = 0; j < filteredItems.length; j++) {
      if (filteredItems[j].path === path) {
        toIndex = j;
        break;
      }
    }
    if (toIndex === -1 || fromIndex === toIndex) {
      return;
    }

    wallpaperGridView.animateMovement = true;
    wallpaperModel.move(fromIndex, toIndex, 1);
    animateMovementResetTimer.restart();
  }

  // Reorder in place instead of clear+rebuild, which would destroy delegates
  // and flash their thumbnails.
  function reconcileModel() {
    for (let i = 0; i < filteredItems.length; i++) {
      let currentPos = -1;
      for (let j = i; j < wallpaperModel.count; j++) {
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

  // Move animations are only wanted for favorite toggles; turn them back off
  // once the move settles so sorting and navigation rebuild silently.
  Timer {
    id: animateMovementResetTimer

    readonly property int settleDelay: 50

    interval: Style.animationNormal + settleDelay
    onTriggered: {
      wallpaperGridView.animateMovement = false;
      root.reconcileModel();
    }
  }

  // -------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------
  function selectItem(path, isDirectory) {
    if (isDirectory) {
      WallpaperService.setBrowsePath(targetScreen.name, path);
      return;
    }

    const screenName = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : targetScreen.name;
    const screenObject = targetScreen;
    const appearance = WallpaperService.wallpaperSelectionAppearance;
    // Ticket taken before the async resolution probe: a second, faster pick
    // for this screen makes this one stale, so the last pick always wins.
    const applyTicket = WallpaperService.beginApplyIntent(screenName);

    WallpaperUpscaleService.probeImageResolution(path, function (width, height) {
      if (!WallpaperService.isApplyIntentCurrent(applyTicket)) {
        return;
      }

      const lowRes = width > 0 && height > 0 && WallpaperUpscaleService.isLowRes(width, height, screenObject);
      if (!lowRes || !root.upscalePrompt) {
        root._applyWallpaper(path, screenName, appearance);
        return;
      }

      root.upscalePrompt.show(screenObject, width, height, function (resolve) {
        resolve(path, ""); // already local, resolves immediately
      }, function (decision, upscaledPath) {
        if (decision === "cancel" || !WallpaperService.isApplyIntentCurrent(applyTicket)) {
          return;
        }
        root._applyWallpaper(decision === "upscaled" ? upscaledPath : path, screenName, appearance);
      });
    });
  }

  function _applyWallpaper(path, screenName, appearance) {
    WallpaperService.changeWallpaper(path, screenName, appearance);
    WallpaperService.applyFavoriteTheme(path, screenName, appearance);
  }

  function toggleFavorite(path) {
    const monitor = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : targetScreen?.name;
    WallpaperService.toggleFavorite(path, WallpaperService.wallpaperSelectionAppearance, monitor);
  }

  function activateCurrentIndex() {
    const index = wallpaperGridView.currentIndex;
    if (index < 0 || index >= wallpaperModel.count) {
      return;
    }
    const item = wallpaperModel.get(index);
    selectItem(item.path, item.isDirectory);
  }

  // View mode cycles single -> recursive -> browse.
  function cycleViewMode() {
    const mode = Settings.data.wallpaper.viewMode;
    Settings.data.wallpaper.viewMode = mode === "single" ? "recursive" : (mode === "recursive" ? "browse" : "single");
  }

  function viewModeIcon() {
    const mode = Settings.data.wallpaper.viewMode;
    if (mode === "single") {
      return "folder";
    }
    return mode === "recursive" ? "folders" : "folder-open";
  }

  function viewModeTooltip() {
    const mode = Settings.data.wallpaper.viewMode;
    let modeName;
    if (mode === "single") {
      modeName = I18n.tr("panels.wallpaper.view-mode-single");
    } else if (mode === "recursive") {
      modeName = I18n.tr("panels.wallpaper.view-mode-recursive");
    } else {
      modeName = I18n.tr("panels.wallpaper.view-mode-browse");
    }
    return I18n.tr("panels.wallpaper.view-mode-cycle-tooltip").replace("{mode}", modeName);
  }

  // Sort cycle: A-Z -> newest -> oldest -> Z-A -> random -> A-Z
  readonly property var _sortCycle: ["name", "date_desc", "date_asc", "name_desc", "random"]

  function nextSortOrder() {
    const current = Settings.data.wallpaper.sortOrder || "name";
    const index = _sortCycle.indexOf(current);
    return _sortCycle[(index + 1) % _sortCycle.length];
  }

  // -------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginM

    // Navigation (left) + view actions (right)
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIconButton {
        icon: "arrow-left"
        tooltipText: I18n.tr("wallpaper.browse.go-up")
        enabled: root.isBrowseMode && root.currentBrowsePath !== root.rootDirectory
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: WallpaperService.navigateUp(root.targetScreen?.name ?? "")
      }

      NIconButton {
        icon: "home"
        tooltipText: I18n.tr("wallpaper.browse.go-root")
        enabled: root.isBrowseMode && root.currentBrowsePath !== root.rootDirectory
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: WallpaperService.navigateToRoot(root.targetScreen?.name ?? "")
      }

      NScrollText {
        text: root.isBrowseMode ? root.currentBrowsePath : root.rootDirectory
        Layout.fillWidth: true
        scrollMode: NScrollText.ScrollMode.Hover
        fadeCornerRadius: Style.radiusM

        NText {
          text: root.isBrowseMode ? root.currentBrowsePath : root.rootDirectory
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
      }

      NIconButton {
        readonly property string sortOrder: Settings.data.wallpaper.sortOrder || "name"

        icon: {
          switch (sortOrder) {
          case "date_desc":
            return "clock";
          case "date_asc":
            return "history";
          case "name_desc":
            return "sort-descending";
          case "random":
            return "arrows-shuffle";
          default:
            return "sort-ascending";
          }
        }
        tooltipText: {
          switch (sortOrder) {
          case "date_desc":
            return I18n.tr("wallpaper.panel.sort-date-desc");
          case "date_asc":
            return I18n.tr("wallpaper.panel.sort-date-asc");
          case "name_desc":
            return I18n.tr("wallpaper.panel.sort-name-desc");
          case "random":
            return I18n.tr("wallpaper.panel.sort-random");
          default:
            return I18n.tr("wallpaper.panel.sort-name-asc");
          }
        }
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: Settings.data.wallpaper.sortOrder = root.nextSortOrder()
      }

      NIconButton {
        icon: root.viewModeIcon()
        tooltipText: root.viewModeTooltip()
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: root.cycleViewMode()
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
          if (root.isBrowseMode) {
            root.refreshWallpaperScreenData();
          } else {
            WallpaperService.refreshWallpapersList();
          }
        }
      }
    }

    // Grid + its empty/scanning overlay share the same box so the layout
    // never jumps between states.
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      NGridView {
        id: wallpaperGridView

        anchors.fill: parent

        visible: !WallpaperService.scanning && wallpaperModel.count > 0
        interactive: true
        keyNavigationEnabled: true
        keyNavigationWraps: false
        highlightFollowsCurrentItem: false
        currentIndex: -1
        reuseItems: true

        model: wallpaperModel

        readonly property int columns: ((root.targetScreen?.width ?? 1920) > 1920) ? 5 : 4
        readonly property int itemSize: cellWidth

        cellWidth: Math.floor((availableWidth - leftMargin - rightMargin) / columns)
        cellHeight: Math.floor(itemSize * 0.7) + Style.marginXS + Style.fontSizeXS + Style.marginM

        leftMargin: Style.marginS
        rightMargin: Style.marginS
        topMargin: Style.marginS
        bottomMargin: Style.marginS

        Component.onCompleted: positionViewAtBeginning()

        onCurrentIndexChanged: {
          if (currentIndex >= 0) {
            positionViewAtIndex(currentIndex, GridView.Contain);
          }
        }

        onKeyPressed: event => {
          if (Keybinds.checkKey(event, 'enter', Settings)) {
            root.activateCurrentIndex();
            event.accepted = true;
          }
        }

        delegate: WallpaperGridCard {
          id: card

          required property int index
          required property var model

          // Re-read the favorite entry when the global revision bumps, when
          // this specific entry is refreshed, or when link mode changes.
          property int favoriteRevision: 0
          readonly property var favoriteData: {
            WallpaperService.favoritesRevision;
            favoriteRevision;
            Settings.data.wallpaper.linkLightAndDarkWallpapers;
            return model.isDirectory ? null : WallpaperService.getFavoriteForDisplay(model.path);
          }

          width: wallpaperGridView.cellWidth
          height: wallpaperGridView.cellHeight
          imageHeight: Math.round(wallpaperGridView.itemSize * 0.67)

          sourcePath: model.path
          useThumbnailCache: true
          label: model.name
          isDirectory: model.isDirectory
          showLabel: !Settings.data.wallpaper.hideWallpaperFilenames
          isSelected: !model.isDirectory && model.path === root.currentWallpaper
          isCurrent: wallpaperGridView.currentIndex === index

          favoriteEnabled: true
          isFavorited: !!favoriteData
          paletteColors: favoriteData?.paletteColors ?? []
          showAppearanceBadge: Settings.data.wallpaper.linkLightAndDarkWallpapers
          paletteAppearanceDark: {
            if (!favoriteData) {
              return false;
            }
            if (favoriteData.appearance === "dark") {
              return true;
            }
            if (favoriteData.appearance === "light") {
              return false;
            }
            return favoriteData.darkMode === true;
          }

          // Single tap only moves the cursor, which updates the side preview.
          onSelected: {
            wallpaperGridView.forceActiveFocus();
            wallpaperGridView.currentIndex = index;
            // Folders are navigation, not a preview target: open them right away.
            if (model.isDirectory) {
              root.selectItem(model.path, true);
            }
          }
          onActivated: {
            wallpaperGridView.forceActiveFocus();
            wallpaperGridView.currentIndex = index;
            root.selectItem(model.path, model.isDirectory);
          }
          onFavoriteToggled: root.toggleFavorite(model.path)

          Connections {
            target: WallpaperService

            function onFavoriteDataUpdated(updatedPath) {
              if (updatedPath === card.model.path) {
                card.favoriteRevision++;
              }
            }
          }
        }
      }

      // Scanning / empty state
      Rectangle {
        anchors.fill: parent
        color: Color.mSurfaceContainerLow
        radius: Style.radiusL
        visible: WallpaperService.scanning || wallpaperModel.count === 0

        ColumnLayout {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.margin2L, 420 * Style.uiScaleRatio)
          spacing: Style.marginM

          NBusyIndicator {
            visible: WallpaperService.scanning
            running: visible
            Layout.alignment: Qt.AlignHCenter
          }

          NIcon {
            visible: !WallpaperService.scanning
            icon: "folder-open"
            pointSize: Style.fontSizeXXL
            color: Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            visible: !WallpaperService.scanning
            text: (root.filterText && root.filterText.length > 0) ? I18n.tr("wallpaper.no-match") : (root.isBrowseMode ? I18n.tr("wallpaper.browse.empty-directory") : I18n.tr("wallpaper.no-wallpaper"))
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }

          NText {
            visible: !WallpaperService.scanning
            text: (root.filterText && root.filterText.length > 0) ? I18n.tr("wallpaper.try-different-search") : (root.isBrowseMode ? I18n.tr("wallpaper.browse.go-up-hint") : I18n.tr("wallpaper.configure-directory"))
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }
        }
      }
    }
  }
}
