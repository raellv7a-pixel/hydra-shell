import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets

import qs.Commons
import qs.Widgets

NBox {
  id: entry

  // Laid out by LauncherRowDelegate, which owns the row metrics and the index
  // of the entry this cell shows.
  required property var modelData
  required property int entryIndex
  required property var launcher

  property bool isContextMenuTarget: launcher.appPanelItem === modelData
  // An open panel owns the highlight: hovering other entries must not steal it,
  // or the panel would end up hanging off an entry that no longer looks selected.
  property bool hoverActive: !launcher.ignoreMouseHover && !launcher.appPanelOpen && mouseArea.containsMouse
  property bool isSelected: isContextMenuTarget || hoverActive || (entryIndex === launcher.selectedIndex)
  property bool isHovered: hoverActive && !isSelected
  // In a single-column list the inline panel expands right underneath this entry,
  // so the two are fused into one Material 3 connected group: tight facing
  // corners, no outline, and the tonal fills carry the grouping instead.
  readonly property bool isPanelAnchor: isContextMenuTarget && launcher.rowColumns === 1

  clip: false
  radius: Style.radiusL
  bottomLeftRadius: entry.isPanelAnchor ? Style.radiusXXS : Style.radiusL
  bottomRightRadius: entry.isPanelAnchor ? Style.radiusXXS : Style.radiusL
  color: entry.isSelected ? Color.mPrimaryContainer : (entry.isHovered ? Color.mSurfaceContainerHigh : "transparent")
  border.color: (entry.isContextMenuTarget && !entry.isPanelAnchor) ? Color.mPrimary : "transparent"
  border.width: (entry.isContextMenuTarget && !entry.isPanelAnchor) ? Style.borderM : 0
  z: entry.isContextMenuTarget ? 10 : 0
  scale: mouseArea.pressed ? 0.975 : (entry.isSelected ? 1.0 : 0.988)
  transformOrigin: Item.Center
  Accessible.role: Accessible.ListItem
  Accessible.name: modelData.name || ""
  Accessible.description: modelData.description || ""
  Accessible.selected: entry.isSelected

  // Prepare item when it becomes visible (e.g., decode images)
  Component.onCompleted: {
    var provider = modelData.provider;
    if (provider && provider.prepareItem) {
      provider.prepareItem(modelData);
    }
  }

  Behavior on color {
    ColorAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutQuint
    }
  }

  Behavior on scale {
    ScaleAnimator {
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  // Focus indicator bar on the left edge
  Rectangle {
    id: focusIndicator
    anchors.left: parent.left
    anchors.leftMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    width: 4
    height: Math.round(parent.height * 0.60)
    radius: 4
    color: Color.mPrimary
    opacity: entry.isSelected ? 0.9 : 0.0
    scale: entry.isSelected ? 1.0 : 0.34
    transformOrigin: Item.Center
    z: 5

    Behavior on scale { ScaleAnimator { duration: Style.animationFast; easing.type: Easing.OutCubic } }
    Behavior on opacity { OpacityAnimator { duration: Style.animationFast; easing.type: Easing.OutCubic } }
  }

  ColumnLayout {
    id: contentLayout
    anchors.fill: parent
    anchors.leftMargin: Style.marginL
    anchors.rightMargin: Style.marginL
    anchors.topMargin: launcher.isCompactDensity ? Style.marginXS : Style.marginM
    anchors.bottomMargin: launcher.isCompactDensity ? Style.marginXS : Style.marginM
    spacing: launcher.isCompactDensity ? Style.marginXS : Style.marginM

    // Top row - Main entry content with action buttons
    RowLayout {
      Layout.fillWidth: true
      spacing: launcher.isCompactDensity ? Style.marginS : Style.marginM

      // Icon badge or Image preview or Emoji
      Item {
        visible: !modelData.hideIcon
        Layout.preferredWidth: modelData.hideIcon ? 0 : launcher.badgeSize
        Layout.preferredHeight: modelData.hideIcon ? 0 : launcher.badgeSize
        scale: entry.isSelected ? 1.08 : 1.0
        opacity: entry.isSelected ? 1.0 : 0.85

        Behavior on scale {
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutQuint
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutQuint
          }
        }
        // Icon background
        Rectangle {
          anchors.fill: parent
          radius: Style.radiusXS
          color: Color.mSurfaceContainerHighest
          visible: Settings.data.appLauncher.showIconBackground && !modelData.isImage
        }

        // Image preview - uses provider's getImageUrl if available
        NImageRounded {
          id: imagePreview
          anchors.fill: parent
          visible: !!modelData.isImage && !modelData.displayString
          radius: Style.radiusXS
          borderColor: Color.mOnSurface
          borderWidth: Style.borderM
          imageFillMode: Image.PreserveAspectCrop

          // Use provider's image revision for reactive updates
          readonly property int _rev: modelData.provider && modelData.provider.imageRevision ? modelData.provider.imageRevision : 0

          // Get image URL from provider
          imagePath: {
            _rev;
            var provider = modelData.provider;
            if (provider && provider.getImageUrl) {
              return provider.getImageUrl(modelData);
            }
            return "";
          }

          Rectangle {
            anchors.fill: parent
            visible: parent.status === Image.Loading
            color: Color.mSurfaceContainerHigh

            BusyIndicator {
              anchors.centerIn: parent
              running: true
              width: Style.baseWidgetSize * 0.5
              height: width
            }
          }

          onStatusChanged: status => {
                             if (status === Image.Error) {
                               iconLoader.visible = true;
                               imagePreview.visible = false;
                             }
                           }
        }

        // Color swatch - shown for clipboard color entries
        Rectangle {
          anchors.fill: parent
          radius: Style.radiusXS
          color: modelData.colorHex || "transparent"
          visible: !!modelData.colorHex
          border.color: Color.mOnSurface
          border.width: Style.borderM
        }

        Loader {
          id: iconLoader
          anchors.fill: parent
          anchors.margins: Style.marginXS

          visible: (!modelData.isImage && !modelData.displayString && !modelData.colorHex) || (!!modelData.isImage && imagePreview.status === Image.Error)
          active: visible

          sourceComponent: Component {
            Loader {
              anchors.fill: parent
              sourceComponent: Settings.data.appLauncher.iconMode === "tabler" && modelData.isTablerIcon ? tablerIconComponent : systemIconComponent
            }
          }

          Component {
            id: tablerIconComponent
            NIcon {
              icon: modelData.icon
              pointSize: Style.fontSizeXXXL
              visible: modelData.icon && !modelData.displayString
              color: Settings.data.appLauncher.showIconBackground ? Color.mOnSurface : (entry.isSelected ? Color.mOnPrimaryContainer : Color.mOnSurface)
            }
          }

          Component {
            id: systemIconComponent
            IconImage {
              anchors.fill: parent
              source: modelData.icon ? ThemeIcons.iconFromName(modelData.icon, "application-x-executable") : ""
              visible: modelData.icon && source !== "" && !modelData.displayString
              asynchronous: true
            }
          }
        }

        // String display - takes precedence when displayString is present
        NText {
          id: stringDisplay
          anchors.centerIn: parent
          visible: !!modelData.displayString || (!imagePreview.visible && !iconLoader.visible)
          text: modelData.displayString ? modelData.displayString : (modelData.name ? modelData.name.charAt(0).toUpperCase() : "?")
          pointSize: modelData.displayString ? (modelData.displayStringSize || Style.fontSizeXXXL) : Style.fontSizeXXL
          font.weight: Style.fontWeightBold
          color: modelData.displayString ? Color.mOnSurface : (entry.isSelected ? Color.mOnPrimaryContainer : Color.mOnSurface)
        }

        // Image type indicator overlay
        Rectangle {
          visible: !!modelData.isImage && imagePreview.visible
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          anchors.margins: 2
          width: formatLabel.width + Style.marginXS
          height: formatLabel.height + Style.marginXXS
          color: Color.mSurfaceContainerHighest
          radius: Style.radiusXXS
          NText {
            id: formatLabel
            anchors.centerIn: parent
            text: {
              if (!modelData.isImage)
                return "";
              const desc = modelData.description || "";
              const parts = desc.split(" \u2022 ");
              return parts[0] || "IMG";
            }
            pointSize: Style.fontSizeXXS
            color: Color.mOnSurfaceVariant
          }
        }

        // Badge icon overlay (generic indicator for any provider)
        Rectangle {
          visible: !!modelData.badgeIcon
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          anchors.margins: 2
          width: height
          height: Style.fontSizeM + Style.marginXS
          color: Color.mSurfaceContainerHighest
          radius: Style.radiusXXS
          NIcon {
            anchors.centerIn: parent
            icon: modelData.badgeIcon || ""
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }
      }

      // Text content (Title on top, description on the line below)
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.marginXXS

        NText {
          text: modelData.name || "Unknown"
          pointSize: Style.fontSizeM
          font.weight: Font.Bold
          color: entry.isSelected ? Color.mOnPrimaryContainer : Color.mOnSurface
          elide: Text.ElideRight
          maximumLineCount: 1
          Layout.fillWidth: true

          Behavior on color {
            ColorAnimation {
              duration: Style.animationNormal
              easing.type: Easing.OutQuint
            }
          }
        }

        NText {
          text: modelData.description || ""
          pointSize: Style.fontSizeS
          color: entry.isSelected ? Qt.alpha(Color.mOnPrimaryContainer, 0.78) : Color.mOnSurfaceVariant
          elide: Text.ElideRight
          maximumLineCount: 1
          Layout.fillWidth: true
          visible: text !== "" && !launcher.isCompactDensity

          Behavior on color {
            ColorAnimation {
              duration: Style.animationNormal
              easing.type: Easing.OutQuint
            }
          }
        }
      }

    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    z: -1
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    enabled: !Settings.data.appLauncher.ignoreMouseInput
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onEntered: {
      if (!launcher.ignoreMouseHover && !launcher.appPanelOpen)
        launcher.selectedIndex = entry.entryIndex;
    }
    onClicked: mouse => {
                 launcher.selectedIndex = entry.entryIndex;
                 if (mouse.button === Qt.RightButton) {
                   launcher.toggleAppPanel(modelData);
                   mouse.accepted = true;
                 } else if (mouse.button === Qt.LeftButton) {
                   launcher.activate();
                   mouse.accepted = true;
                 }
               }
  }
}
