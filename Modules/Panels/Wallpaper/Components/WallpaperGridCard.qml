import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Single card used by every wallpaper grid (local gallery, Wallhaven, and any
// future provider). It owns the thumbnail lifecycle — including cache lookup
// and delegate recycling — so a visual fix lands in one place instead of being
// copied across each view's inline delegate.
Item {
  id: card

  // ---- data ----------------------------------------------------------
  // Local file path or remote thumbnail URL; also the card's identity.
  property string sourcePath: ""
  // Resolve sourcePath through the thumbnail cache (local files) instead of
  // handing it to the image loader as-is (remote URLs).
  property bool useThumbnailCache: false
  property string label: ""
  property bool isDirectory: false

  // ---- state ---------------------------------------------------------
  property bool isSelected: false // currently applied wallpaper
  property bool isCurrent: false // keyboard cursor is on this cell
  property bool busy: false // download / apply in flight
  property bool showLabel: true

  // ---- favorites (local gallery only) --------------------------------
  property bool favoriteEnabled: false
  property bool isFavorited: false
  property var paletteColors: []
  property bool paletteAppearanceDark: false
  property bool showAppearanceBadge: false

  // ---- geometry ------------------------------------------------------
  property real imageHeight: Math.round(height * 0.72)

  // A single tap only selects the card (which drives the side preview);
  // committing the wallpaper takes a double tap, Enter, or the Apply button.
  signal selected
  signal activated
  signal favoriteToggled

  readonly property bool hovered: hoverHandler.hovered
  readonly property bool active: hoverHandler.hovered || isSelected || isCurrent
  readonly property string resolvedSource: _cachedSource
  readonly property bool thumbnailPending: !isDirectory && (_cachedSource === "" || thumbnail.status === Image.Loading)

  // Cache lookups are async, so the resolved path is state rather than a
  // binding; it is recomputed on creation, on path change and on reuse.
  property string _cachedSource: ""
  property int _resolveGeneration: 0

  function refreshThumbnail() {
    const generation = ++_resolveGeneration;
    if (isDirectory || sourcePath === "") {
      _cachedSource = "";
      return;
    }
    if (!useThumbnailCache || !ImageCacheService.initialized) {
      _cachedSource = sourcePath;
      return;
    }
    _cachedSource = "";
    const requestedPath = sourcePath;
    ImageCacheService.getThumbnail(sourcePath, function (path, success) {
      // Drop the answer if the cell was recycled onto another wallpaper.
      if (generation !== card._resolveGeneration || requestedPath !== card.sourcePath) {
        return;
      }
      card._cachedSource = success ? path : requestedPath;
    });
  }

  onSourcePathChanged: refreshThumbnail()
  Component.onCompleted: refreshThumbnail()

  // Recycled cells must not show the previous wallpaper for a frame.
  GridView.onPooled: {
    _resolveGeneration++;
    _cachedSource = "";
    TooltipService.hide(card);
  }
  GridView.onReused: refreshThumbnail()

  Accessible.role: Accessible.ListItem
  Accessible.name: label
  Accessible.selected: isSelected || isCurrent

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginXS
    spacing: Style.marginXS

    Item {
      id: imageContainer

      Layout.fillWidth: true
      Layout.fillHeight: true

      // Directory tile
      Rectangle {
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
        }
        height: card.imageHeight
        color: Color.mSurfaceContainerHigh
        radius: Style.radiusL
        visible: card.isDirectory
        border.color: card.isCurrent ? Color.mPrimary : "transparent"
        border.width: card.isCurrent ? Style.borderL : 0

        NIcon {
          anchors.centerIn: parent
          icon: "folder"
          pointSize: Style.fontSizeXXXL
          color: Color.mPrimary
        }
      }

      NImageRounded {
        id: thumbnail

        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
        }
        height: card.imageHeight
        visible: !card.isDirectory
        imagePath: card._cachedSource
        radius: Style.radiusL
        borderColor: (card.isSelected || card.isCurrent) ? Color.mPrimary : "transparent"
        borderWidth: (card.isSelected || card.isCurrent) ? Style.borderL : 0
        imageFillMode: Image.PreserveAspectCrop
      }

      // Placeholder while loading or on failure
      Rectangle {
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
        }
        height: card.imageHeight
        color: Color.mSurfaceContainerHigh
        radius: Style.radiusL
        visible: !card.isDirectory && (thumbnail.status === Image.Loading || thumbnail.status === Image.Error || card._cachedSource === "")

        NIcon {
          anchors.centerIn: parent
          icon: thumbnail.status === Image.Error ? "alert-circle" : "image"
          pointSize: Style.fontSizeL
          color: Color.mOnSurfaceVariant
        }
      }

      NBusyIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (card.imageHeight - height) / 2
        z: 12
        visible: card.busy || card.thumbnailPending
        running: visible
        size: Math.round(18 * Style.uiScaleRatio)
      }

      // Applied badge
      Rectangle {
        anchors {
          top: parent.top
          right: parent.right
          margins: Style.marginS
        }
        width: Math.round(Style.baseWidgetSize * 0.7)
        height: width
        radius: width / 2
        z: 6
        color: Color.mPrimaryContainer
        visible: card.isSelected

        NIcon {
          anchors.centerIn: parent
          icon: "check"
          pointSize: Style.fontSizeM
          color: Color.mOnPrimaryContainer
        }
      }

      // Favorite star
      Rectangle {
        id: starButton

        anchors {
          top: parent.top
          left: parent.left
          margins: Style.marginS
        }
        width: Math.round(Style.baseWidgetSize * 0.7)
        height: width
        radius: width / 2
        z: 11
        visible: card.favoriteEnabled && !card.isDirectory && (card.isFavorited || hoverHandler.hovered || card.isCurrent)
        color: {
          if (card.isFavorited) {
            return starHoverHandler.hovered ? Color.mPrimaryContainer : Color.mSecondaryContainer;
          }
          return starHoverHandler.hovered ? Color.mSurfaceContainerHighest : Color.mSurfaceContainerHigh;
        }
        opacity: (card.isFavorited || starHoverHandler.hovered) ? 1.0 : 0.7

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
          anchors.centerIn: parent
          icon: card.isFavorited ? "star-filled" : "star"
          pointSize: Style.fontSizeM
          color: {
            if (card.isFavorited) {
              return starHoverHandler.hovered ? Color.mOnPrimaryContainer : Color.mOnSecondaryContainer;
            }
            return starHoverHandler.hovered ? Color.mOnSurface : Color.mOnSurfaceVariant;
          }
        }

        HoverHandler {
          id: starHoverHandler
        }

        TapHandler {
          onTapped: card.favoriteToggled()
        }
      }

      // Palette dots of a favorited wallpaper — taps must not fall through
      // to the card's activation handler.
      Item {
        id: paletteRow

        readonly property int diameter: Math.round(25 * Style.uiScaleRatio)

        anchors {
          bottom: thumbnail.bottom
          horizontalCenter: parent.horizontalCenter
          bottomMargin: Style.marginS
        }
        z: 10
        implicitWidth: paletteRowContent.implicitWidth
        implicitHeight: paletteRowContent.implicitHeight
        width: implicitWidth
        height: implicitHeight
        visible: card.favoriteEnabled && card.isFavorited && card.paletteColors.length > 0

        Row {
          id: paletteRowContent

          spacing: Style.marginXS

          Rectangle {
            width: paletteRow.diameter
            height: paletteRow.diameter
            radius: width * 0.5
            visible: card.showAppearanceBadge
            color: Color.mSurface
            border.color: Color.mShadow
            border.width: Style.borderS

            NIcon {
              anchors.centerIn: parent
              icon: card.paletteAppearanceDark ? "moon" : "sun"
              pointSize: parent.width * 0.45
              color: Color.mOnSurface
            }
          }

          Repeater {
            model: card.paletteColors

            Rectangle {
              required property var modelData

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

      // Idle veil, lifted on hover/selection
      Rectangle {
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
        }
        height: card.imageHeight
        color: Color.mSurface
        radius: Style.radiusL
        opacity: card.active ? 0 : 0.18

        Behavior on opacity {
          NumberAnimation {
            duration: Style.animationFast
          }
        }
      }

      HoverHandler {
        id: hoverHandler

        // Truncated names are unreadable without this; the tooltip is the
        // only way to tell two similar filenames apart before applying one.
        onHoveredChanged: {
          if (hovered && card.label !== "") {
            TooltipService.show(card, card.label, "top");
          } else {
            TooltipService.hide(card);
          }
        }
      }

      TapHandler {
        enabled: !card.busy
        onSingleTapped: card.selected()
        onDoubleTapped: card.activated()
      }
    }

    NText {
      text: card.label
      visible: card.showLabel
      color: card.active ? Color.mOnSurface : Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginS
      Layout.rightMargin: Style.marginS
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }

  Component.onDestruction: TooltipService.hide(card)
}
