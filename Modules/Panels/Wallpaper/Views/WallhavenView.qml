import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Components"
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Wallhaven browser: results grid, pagination and the download/apply flow.
Item {
  id: root

  // Index of the screen tab the panel is showing, used as the apply target.
  property int screenIndex: 0
  // Shared low-resolution warning modal, provided by the panel.
  property Item upscalePrompt: null

  property alias gridView: wallhavenGridView
  property alias pageInput: pageInput

  property var wallpapers: []
  property bool loading: false
  property string errorMessage: ""
  property bool initialized: false

  // Wallpaper the side preview should show: whatever the grid cursor is on.
  // The large thumbnail is enough for the mock-up; the full file is only
  // downloaded when the user actually applies it.
  readonly property var currentCandidate: {
    const index = wallhavenGridView.currentIndex;
    if (index < 0 || index >= wallpapers.length) {
      return null;
    }
    const wallpaper = wallpapers[index];
    if (!wallpaper) {
      return null;
    }
    return {
      "source": "wallhaven",
      "path": WallhavenService.getThumbnailUrl(wallpaper, "original"),
      "title": wallpaper.id || I18n.tr("common.unknown"),
      "data": wallpaper,
      "meta": {
        "resolution": wallpaper.resolution || "",
        "format": wallpaper.file_type || "",
        "sizeBytes": wallpaper.file_size || 0,
        "category": wallpaper.category || "",
        "purity": wallpaper.purity || "",
        "views": wallpaper.views || 0,
        "favorites": wallpaper.favorites || 0,
        "url": wallpaper.url || ""
      }
    };
  }

  // Emitted whenever the cursor lands on a different wallpaper.
  signal previewRequested(var candidate)

  onCurrentCandidateChanged: previewRequested(currentCandidate)

  // Emitted when the view wants the panel's search field to adopt a query
  // (currently "find similar" from the preview pane).
  signal searchQueryRequested(string query)

  Component.onCompleted: {
    if (Settings.data.wallpaper.useWallhaven) {
      activate(false);
    }
  }

  Connections {
    target: WallhavenService

    function onSearchCompleted(results, meta) {
      root.wallpapers = results || [];
      root.loading = false;
      root.errorMessage = "";
    }

    function onSearchFailed(error) {
      root.loading = false;
      root.errorMessage = error || "";
    }
  }

  function activate(forceRefresh) {
    initialized = true;
    loading = true;
    errorMessage = "";
    WallhavenService.syncFromSettings();
    const query = Settings.data.wallpaper.wallhavenQuery || "";
    const page = WallhavenService.currentQuery === query ? WallhavenService.currentPage : 1;
    WallhavenService.search(query, page, forceRefresh === true);
  }

  function search(query) {
    loading = true;
    WallhavenService.search(query, 1);
  }

  function activateCurrentIndex() {
    if (wallhavenGridView.currentIndex >= 0 && wallhavenGridView.currentIndex < wallpapers.length) {
      downloadAndApply(wallpapers[wallhavenGridView.currentIndex]);
    }
  }

  // -------------------------------------------------------------------
  // Apply flow
  // -------------------------------------------------------------------
  function _dimensions(wallpaper) {
    if (wallpaper && wallpaper.dimension_x && wallpaper.dimension_y) {
      return {
        "w": Number(wallpaper.dimension_x),
        "h": Number(wallpaper.dimension_y)
      };
    }
    const match = /^(\d+)x(\d+)$/.exec(wallpaper?.resolution || "");
    if (!match) {
      return null;
    }
    return {
      "w": Number(match[1]),
      "h": Number(match[2])
    };
  }

  function downloadAndApply(wallpaper, targetScreen) {
    const applyToAll = Settings.data.wallpaper.setWallpaperOnAllMonitors;
    const selectedScreen = (screenIndex >= 0 && screenIndex < Quickshell.screens.length) ? Quickshell.screens[screenIndex] : null;
    const explicitScreenName = typeof targetScreen === "string" ? targetScreen : targetScreen?.name;
    const screenName = applyToAll ? undefined : (explicitScreenName || selectedScreen?.name);
    const screenObject = explicitScreenName ? Quickshell.screens.find(s => s.name === explicitScreenName) : selectedScreen;
    const appearance = WallpaperService.wallpaperSelectionAppearance;
    // Ticket taken before the download starts, so a later pick for the same
    // screen invalidates this one: rapid picks converge on the last request
    // instead of whichever download happens to finish last.
    const applyTicket = WallpaperService.beginApplyIntent(screenName);

    const dims = _dimensions(wallpaper);
    const lowRes = dims && screenObject && WallpaperUpscaleService.isLowRes(dims.w, dims.h, screenObject);
    if (!lowRes || !upscalePrompt) {
      _proceedApply(wallpaper, screenName, appearance, applyTicket);
      return;
    }

    upscalePrompt.show(screenObject, dims.w, dims.h, function (resolve) {
      // Only resolved when the user picks the AI upscale — no point paying
      // for the download just to show a warning.
      WallhavenService.downloadWallpaper(wallpaper, function (success, localPath) {
        resolve(success ? localPath : "", success ? "" : I18n.tr("wallpaper.wallhaven.download-failed"));
      });
    }, function (decision, upscaledPath) {
      if (decision === "cancel") {
        return;
      }
      if (decision === "upscaled") {
        if (WallpaperService.isApplyIntentCurrent(applyTicket)) {
          root._apply(upscaledPath, screenName, appearance);
        }
        return;
      }
      root._proceedApply(wallpaper, screenName, appearance, applyTicket);
    });
  }

  function _proceedApply(wallpaper, screenName, appearance, applyTicket) {
    WallhavenService.downloadWallpaper(wallpaper, function (success, localPath) {
      if (!WallpaperService.isApplyIntentCurrent(applyTicket)) {
        return;
      }
      if (success) {
        root._apply(localPath, screenName, appearance);
      } else {
        ToastService.showError("Wallhaven", I18n.tr("wallpaper.wallhaven.download-failed"));
      }
    });
  }

  function _apply(path, screenName, appearance) {
    WallpaperService.changeWallpaper(path, screenName, appearance);
    WallpaperService.applyFavoriteTheme(path, screenName, appearance);
  }

  // -------------------------------------------------------------------
  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginM

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      NGridView {
        id: wallhavenGridView

        anchors.fill: parent

        visible: !root.loading && root.errorMessage === "" && root.wallpapers.length > 0
        interactive: true
        keyNavigationEnabled: true
        keyNavigationWraps: false
        highlightFollowsCurrentItem: false
        currentIndex: -1
        reuseItems: true

        model: root.wallpapers

        readonly property int columns: Math.max(2, Math.min(6, Math.floor(availableWidth / (190 * Style.uiScaleRatio))))
        readonly property int itemSize: cellWidth

        cellWidth: Math.floor((availableWidth - leftMargin - rightMargin) / columns)
        cellHeight: Math.floor(itemSize * 0.7) + Style.marginXS + Style.fontSizeXS + Style.marginM

        leftMargin: Style.marginS
        rightMargin: Style.marginS
        topMargin: Style.marginS
        bottomMargin: Style.marginS

        Component.onCompleted: positionViewAtBeginning()

        onModelChanged: {
          currentIndex = -1;
          positionViewAtBeginning();
        }

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
          required property var modelData

          readonly property string wallpaperId: modelData?.id ?? ""

          width: wallhavenGridView.cellWidth
          height: wallhavenGridView.cellHeight
          imageHeight: Math.round(wallhavenGridView.itemSize * 0.67)

          sourcePath: modelData ? WallhavenService.getThumbnailUrl(modelData, "large") : ""
          label: wallpaperId || I18n.tr("common.unknown")
          showLabel: !Settings.data.wallpaper.hideWallpaperFilenames
          isCurrent: wallhavenGridView.currentIndex === index
          // isDownloading() reads downloadRevision, so this re-evaluates
          // whenever a download starts or finishes.
          busy: WallhavenService.isDownloading(wallpaperId)

          // Single tap only moves the cursor, which updates the side preview.
          onSelected: {
            wallhavenGridView.forceActiveFocus();
            wallhavenGridView.currentIndex = index;
          }
          onActivated: {
            wallhavenGridView.forceActiveFocus();
            wallhavenGridView.currentIndex = index;
            root.downloadAndApply(modelData);
          }
        }
      }

      // Loading overlay — same footprint as the grid so nothing jumps
      Rectangle {
        anchors.fill: parent
        color: Color.mSurfaceContainerLow
        radius: Style.radiusL
        visible: root.loading || WallhavenService.fetching
        z: 10

        ColumnLayout {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.margin2L, 420 * Style.uiScaleRatio)
          spacing: Style.marginM

          NMorphLoader {
            size: Style.baseWidgetSize * 1.5
            color: Color.mPrimary
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            text: WallhavenService.retrySeconds > 0 ? I18n.tr("wallpaper.wallhaven.retrying", {
                                                                "seconds": WallhavenService.retrySeconds
                                                              }) : I18n.tr("wallpaper.wallhaven.loading")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeM
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }
        }
      }

      // Error overlay
      Rectangle {
        anchors.fill: parent
        color: Color.mSurfaceContainerLow
        radius: Style.radiusL
        visible: root.errorMessage !== "" && !root.loading
        z: 10

        ColumnLayout {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.margin2L, 420 * Style.uiScaleRatio)
          spacing: Style.marginM

          NIcon {
            icon: "alert-circle"
            pointSize: Style.fontSizeXXL
            color: Color.mError
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            text: root.errorMessage
            color: Color.mOnSurface
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }

          NButton {
            text: I18n.tr("common.retry")
            icon: "refresh"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.activate(true)
          }
        }
      }

      // Empty state overlay
      Rectangle {
        anchors.fill: parent
        color: Color.mSurfaceContainerLow
        radius: Style.radiusL
        visible: root.wallpapers.length === 0 && !root.loading && root.errorMessage === ""
        z: 10

        ColumnLayout {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.margin2L, 420 * Style.uiScaleRatio)
          spacing: Style.marginM

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
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
          }
        }
      }
    }

    // Pagination
    RowLayout {
      Layout.fillWidth: true
      visible: root.errorMessage === ""
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
        enabled: !root.loading && WallhavenService.currentPage > 1 && !WallhavenService.fetching
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
          enabled: !root.loading && !WallhavenService.fetching
          showClearButton: false

          function submitPage() {
            const page = parseInt(text);
            if (!isNaN(page) && page >= 1 && page <= WallhavenService.lastPage) {
              if (page !== WallhavenService.currentPage) {
                WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", page);
              }
            } else {
              text = "" + WallhavenService.currentPage;
            }
            // Drop focus so the field stops swallowing panel keybinds
            pageInput.inputItem.focus = false;
          }

          onEditingFinished: submitPage()

          Connections {
            target: WallhavenService

            function onCurrentPageChanged() {
              pageInput.text = "" + WallhavenService.currentPage;
            }
          }
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
        onClicked: root.activate(true)
      }

      Item {
        Layout.fillWidth: true
      }
    }
  }

  // Runs a "more like this" search for a wallpaper id, keeping the panel's
  // search field in sync.
  function findSimilar(wallpaperId) {
    const query = "like:" + wallpaperId;
    Settings.data.wallpaper.wallhavenQuery = query;
    searchQueryRequested(query);
    search(query);
  }
}
