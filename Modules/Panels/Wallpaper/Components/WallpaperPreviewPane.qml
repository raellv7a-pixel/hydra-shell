import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Right-hand column of the wallpaper panel: shows the wallpaper the user is
// currently considering (not the one already applied), what it would do to the
// theme, its metadata, and the actions that commit it.
NBox {
  id: root

  // Candidate being previewed, or null to fall back to the applied wallpaper:
  // {
  //   source: "local" | "wallhaven" | "video",
  //   path:   local path or remote preview URL shown in the mock-up,
  //   title:  label shown above the metadata,
  //   data:   provider payload forwarded back on apply,
  //   meta:   { resolution, format, sizeBytes, category, purity, views, favorites, url }
  // }
  property var candidate: null
  // Wallpaper applied to the current screen, shown when there is no candidate.
  property string appliedWallpaperPath: ""
  property string screenName: ""
  // True while the candidate is being downloaded/applied.
  property bool applying: false

  readonly property bool hasCandidate: candidate !== null && candidate !== undefined
  readonly property string previewPath: hasCandidate ? (candidate.path || "") : appliedWallpaperPath
  // The chip must not claim "candidate" once the pick is the live wallpaper.
  readonly property bool showingCandidate: hasCandidate && previewPath !== appliedWallpaperPath
  readonly property var meta: hasCandidate && candidate.meta ? candidate.meta : ({})
  readonly property bool isRemote: hasCandidate && candidate.source === "wallhaven"
  // Local candidates and the applied wallpaper both read their info from disk.
  readonly property bool readsFromDisk: previewPath !== "" && previewPath.startsWith("/")

  signal applyRequested
  signal findSimilarRequested(string wallpaperId)

  color: Color.mSurfaceContainerLow
  radius: Style.radiusCard

  WallpaperFileInfo {
    id: fileInfo

    path: root.readsFromDisk ? root.previewPath : ""
  }

  function _formatBytes(bytes) {
    if (!bytes || bytes <= 0) {
      return "—";
    }
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(0) + " KiB";
    }
    return (bytes / (1024 * 1024)).toFixed(1) + " MiB";
  }

  function _capitalize(value) {
    const text = String(value || "");
    return text.length > 0 ? text.charAt(0).toUpperCase() + text.slice(1) : text;
  }

  function _extensionOf(path) {
    const name = String(path || "").split("/").pop();
    const dot = name.lastIndexOf(".");
    return dot > 0 ? name.slice(dot + 1).toUpperCase() : "—";
  }

  // "1920x1080 · PNG · 2.7 MiB" — from provider metadata when remote, from disk otherwise.
  function primaryInfo() {
    if (previewPath === "") {
      return "";
    }
    if (isRemote) {
      return [meta.resolution || "—", meta.format ? String(meta.format).replace("image/", "").toUpperCase() : "—", _formatBytes(Number(meta.sizeBytes) || 0)].join(" · ");
    }
    return [fileInfo.resolutionText, _extensionOf(previewPath), _formatBytes(fileInfo.fileBytes)].join(" · ");
  }

  // Provider stats for remote picks, modification date for local files.
  function secondaryInfo() {
    if (previewPath === "") {
      return "";
    }
    if (isRemote) {
      return I18n.tr("wallpaper.wallhaven.metadata-secondary", {
                       "category": _capitalize(meta.category || "—"),
                       "purity": String(meta.purity || "—").toUpperCase(),
                       "views": Number(meta.views) || 0,
                       "favorites": Number(meta.favorites) || 0
                     });
    }
    if (fileInfo.modifiedEpoch <= 0) {
      return "";
    }
    return I18n.tr("wallpaper.panel.info-modified", {
                     "date": new Date(fileInfo.modifiedEpoch * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
                   });
  }

  function titleText() {
    if (hasCandidate && candidate.title) {
      return candidate.title;
    }
    if (previewPath === "") {
      return I18n.tr("wallpaper.panel.preview-empty");
    }
    return previewPath.split("/").pop();
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.paddingCard
    spacing: Style.spaceS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spaceXS

      NIcon {
        icon: "device-desktop"
        pointSize: Style.fontSizeTitleSmall
        color: Color.mPrimary
      }

      NText {
        text: I18n.tr("wallpaper.panel.preview-title")
        pointSize: Style.fontSizeTitleSmall
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
      }

      // Makes explicit whether the mock-up shows a pick under consideration or
      // the wallpaper already on screen — the old preview never distinguished them.
      Rectangle {
        Layout.preferredWidth: stateChipText.implicitWidth + Style.spaceXS * 2
        Layout.preferredHeight: stateChipText.implicitHeight + Style.spaceXXS * 2
        radius: height / 2
        color: root.showingCandidate ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh

        NText {
          id: stateChipText

          anchors.centerIn: parent
          text: root.showingCandidate ? I18n.tr("wallpaper.panel.preview-chip-candidate") : I18n.tr("wallpaper.panel.preview-chip-applied")
          pointSize: Style.fontSizeLabelMedium
          font.weight: Style.fontWeightBold
          color: root.showingCandidate ? Color.mOnPrimaryContainer : Color.mOnSurfaceVariant
        }
      }
    }

    NDivider {
      Layout.fillWidth: true
      opacity: 0.35
    }

    // The mock-up is 16:9, so height follows width: letting it fill the
    // column only padded it with empty space around a fixed-size image.
    MockDesktopPreview {
      id: mockPreview

      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(width * 9 / 16)

      wallpaperPath: root.previewPath
      screenName: root.screenName
    }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
    }

    // Metadata card
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: infoColumn.implicitHeight + Style.spaceS * 2
      color: Color.mSurfaceContainerHigh
      radius: Style.radiusCard

      ColumnLayout {
        id: infoColumn

        anchors.fill: parent
        anchors.margins: Style.spaceS
        spacing: Style.spaceXXS

        NText {
          text: root.titleText()
          pointSize: Style.fontSizeBodySmall
          font.weight: Style.fontWeightMedium
          color: Color.mOnSurface
          elide: Text.ElideMiddle
          Layout.fillWidth: true
        }

        NText {
          text: root.primaryInfo()
          visible: text !== ""
          pointSize: Style.fontSizeLabelMedium
          color: Color.mOnSurfaceVariant
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        NText {
          text: root.secondaryInfo()
          visible: text !== ""
          pointSize: Style.fontSizeLabelSmall
          color: Color.mOnSurfaceVariant
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        WallpaperThemeDiffBadge {
          Layout.fillWidth: true
          Layout.topMargin: Style.spaceXXS
          Layout.preferredHeight: visible ? implicitHeight : 0
          currentPalette: mockPreview.colorSnapshot()
          candidatePalette: mockPreview.candidatePalette ? mockPreview.candidatePalette[mockPreview.previewDarkMode ? "dark" : "light"] : null
        }

        // The theme this wallpaper would produce, next to the count of roles
        // it changes — the diff badge alone never showed which colors.
        RowLayout {
          id: candidateSwatches

          readonly property var palette: mockPreview.candidatePalette ? mockPreview.candidatePalette[mockPreview.previewDarkMode ? "dark" : "light"] : null
          readonly property var roles: ["mPrimary", "mSecondary", "mTertiary", "mSurface", "mSurfaceVariant", "mOnSurface"]
          readonly property int diameter: Math.round(18 * Style.uiScaleRatio)

          Layout.fillWidth: true
          Layout.topMargin: Style.spaceXXS
          spacing: Style.spaceXXS
          visible: palette !== null

          Repeater {
            model: candidateSwatches.roles

            Rectangle {
              required property string modelData

              Layout.preferredWidth: candidateSwatches.diameter
              Layout.preferredHeight: candidateSwatches.diameter
              radius: candidateSwatches.diameter / 2
              color: candidateSwatches.palette?.[modelData] ?? "transparent"
              border.color: Qt.alpha(Color.mOnSurface, 0.25)
              border.width: Style.borderS
            }
          }

          Item {
            Layout.fillWidth: true
          }
        }
      }
    }

    // Actions
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spaceXS

      NComboBox {
        Layout.preferredWidth: 130 * Style.uiScaleRatio
        model: WallpaperService.fillModeModel
        currentKey: mockPreview.currentFillMode
        onSelected: key => {
                      mockPreview.currentFillMode = key;
                      Settings.data.wallpaper.fillMode = key;
                    }
      }

      NIconButton {
        icon: mockPreview.previewDarkMode ? "moon" : "sun"
        tooltipText: mockPreview.previewDarkMode ? I18n.tr("wallpaper.panel.preview-light-tooltip") : I18n.tr("wallpaper.panel.preview-dark-tooltip")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: mockPreview.previewDarkMode ? Color.mSecondaryContainer : Color.mSurfaceContainerHighest
        colorFg: mockPreview.previewDarkMode ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: mockPreview.previewDarkMode = !mockPreview.previewDarkMode
      }

      NIconButton {
        visible: root.isRemote
        icon: "photo-search"
        tooltipText: I18n.tr("wallpaper.wallhaven.find-similar")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: Color.mSurfaceContainerHighest
        colorFg: Color.mOnSurfaceVariant
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: {
          if (root.candidate?.data?.id) {
            root.findSimilarRequested(root.candidate.data.id);
          }
        }
      }

      NIconButton {
        visible: root.isRemote && !!root.meta.url
        icon: "external-link"
        tooltipText: I18n.tr("wallpaper.wallhaven.open-browser")
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: Color.mSurfaceContainerHighest
        colorFg: Color.mOnSurfaceVariant
        colorBorder: "transparent"
        colorBorderHover: "transparent"
        onClicked: Qt.openUrlExternally(root.meta.url)
      }

      Item {
        Layout.fillWidth: true
      }

      NButton {
        text: root.applying ? I18n.tr("wallpaper.wallhaven.downloading") : I18n.tr("common.apply")
        icon: root.applying ? "loader-2" : "check"
        enabled: root.previewPath !== "" && !root.applying
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        onClicked: root.applyRequested()
      }
    }
  }
}
