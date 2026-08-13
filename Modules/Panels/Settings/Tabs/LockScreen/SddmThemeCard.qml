import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Single card for the SDDM theme grid in LockScreenTab.qml. Mirrors
// WallpaperGridCard's Material 3 conventions (rounded thumbnail, hover veil,
// applied badge, busy overlay) so the two catalog browsers in Settings look
// and behave the same way.
Item {
  id: card

  required property var themeData

  readonly property string slug: themeData.slug || ""
  readonly property string themeName: themeData.name || slug
  readonly property bool installed: themeData.installed === true
  readonly property string previewUrl: themeData.preview_url || ""
  readonly property string description: themeData.description || ""

  readonly property bool isApplied: installed && !!Settings.data.general && Settings.data.general.sddmTheme === slug
  readonly property bool isInstalling: LockThemeService.installingSlug === slug
  readonly property bool isApplying: LockThemeService.applyingSlug === slug
  readonly property bool busy: isInstalling || isApplying

  readonly property real imageHeight: Math.round(height * 0.78)
  readonly property bool hovered: hoverHandler.hovered

  Accessible.role: Accessible.ListItem
  Accessible.name: themeName
  Accessible.selected: isApplied

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginXS
    spacing: Style.marginXS

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      NImageRounded {
        id: thumbnail
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
        }
        height: card.imageHeight
        imagePath: card.previewUrl
        fallbackIcon: "lock"
        radius: Style.radiusL
        borderColor: card.isApplied ? Color.mPrimary : "transparent"
        borderWidth: card.isApplied ? Style.borderL : 0
        imageFillMode: Image.PreserveAspectCrop
      }

      // Idle veil, lifted on hover/applied — same convention as WallpaperGridCard.
      Rectangle {
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
        }
        height: card.imageHeight
        color: Color.mSurface
        radius: Style.radiusL
        opacity: (card.hovered || card.isApplied) ? 0 : 0.18

        Behavior on opacity {
          NumberAnimation {
            duration: Style.animationFast
          }
        }
      }

      NBusyIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (card.imageHeight - height) / 2
        z: 12
        visible: card.busy
        running: visible
        size: Math.round(22 * Style.uiScaleRatio)
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
        visible: card.isApplied

        NIcon {
          anchors.centerIn: parent
          icon: "check"
          pointSize: Style.fontSizeM
          color: Color.mOnPrimaryContainer
        }
      }

      HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
          if (hovered && card.description !== "") {
            TooltipService.show(card, card.description, "top");
          } else {
            TooltipService.hide(card);
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        text: card.themeName
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeS
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NButton {
        visible: !card.isApplied
        text: card.installed ? I18n.tr("panels.lock-screen.sddm-apply") : I18n.tr("panels.lock-screen.sddm-install")
        icon: card.installed ? "check" : "download"
        outlined: card.installed
        enabled: !card.busy && !LockThemeService.busy
        onClicked: {
          if (card.installed) {
            LockThemeService.applyTheme(card.slug, card.themeData.path);
          } else {
            LockThemeService.installTheme(card.slug);
          }
        }
      }
    }
  }

  Component.onDestruction: TooltipService.hide(card)
}
