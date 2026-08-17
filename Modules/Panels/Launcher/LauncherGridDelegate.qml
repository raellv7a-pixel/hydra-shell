import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets

import qs.Commons
import qs.Widgets

Item {
  id: gridEntryContainer

  // Laid out by LauncherRowDelegate, which owns the cell metrics and the index
  // of the entry this cell shows.
  required property var modelData
  required property int entryIndex
  required property var launcher

  property bool isContextMenuTarget: launcher.appPanelItem === modelData
  // An open panel owns the highlight: hovering other cards must not steal it.
  property bool isSelected: isContextMenuTarget || (!launcher.ignoreMouseHover && !launcher.appPanelOpen && mouseArea.containsMouse) || (entryIndex === launcher.selectedIndex)
  z: isContextMenuTarget ? 10 : 0
  Accessible.role: Accessible.ListItem
  Accessible.name: modelData.name || ""
  Accessible.description: modelData.description || ""
  Accessible.selected: gridEntryContainer.isSelected

  // Prepare item when it becomes visible (e.g., decode images)
  Component.onCompleted: {
    var provider = modelData.provider;
    if (provider && provider.prepareItem) {
      provider.prepareItem(modelData);
    }
  }

  NBox {
    id: gridEntry
    anchors.fill: parent
    anchors.margins: Style.marginXXS
    radius: Style.radiusL
    color: gridEntryContainer.isSelected ? Color.mPrimaryContainer : Color.mSurfaceContainerLow
    forceOpaque: false
    border.color: gridEntryContainer.isContextMenuTarget ? Color.mPrimary : (gridEntryContainer.isSelected ? Color.mPrimary : "transparent")
    border.width: gridEntryContainer.isContextMenuTarget ? Style.borderM : (gridEntryContainer.isSelected ? Style.borderS : 0)
    scale: mouseArea.pressed ? 0.95 : (gridEntryContainer.isSelected ? 1.0 : 0.975)
    transformOrigin: Item.Center

    Behavior on scale {
      ScaleAnimator {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }

    Behavior on color {
      ColorAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutQuint
      }
    }
    Behavior on border.color {
      ColorAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutQuint
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: launcher.isCompactDensity ? Style.marginXS : Style.marginM
      anchors.bottomMargin: launcher.isCompactDensity ? Style.marginXS : Style.marginM
      spacing: launcher.isCompactDensity ? 0 : Style.marginXXS

      // Icon badge or Image preview or Emoji
      Item {
        // Size image at 65% of cell dimensions.
        Layout.preferredWidth: Math.round(gridEntry.width * 0.65)
        Layout.preferredHeight: Math.round(gridEntry.height * 0.65)
        Layout.alignment: Qt.AlignHCenter
        scale: gridEntryContainer.isSelected ? 1.08 : 1.0
        opacity: gridEntryContainer.isSelected ? 1.0 : 0.85

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
          radius: Style.radiusM
          color: Color.mSurfaceContainerHighest
          visible: Settings.data.appLauncher.showIconBackground && !modelData.isImage
        }

        // Image preview - uses provider's getImageUrl if available
        NImageRounded {
          id: gridImagePreview
          anchors.fill: parent
          visible: !!modelData.isImage && !modelData.displayString
          radius: Style.radiusM

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
              gridIconLoader.visible = true;
              gridImagePreview.visible = false;
            }
          }
        }

        Loader {
          id: gridIconLoader
          anchors.fill: parent
          anchors.margins: Style.marginXS

          visible: (!modelData.isImage && !modelData.displayString) || (!!modelData.isImage && gridImagePreview.status === Image.Error)
          active: visible

          sourceComponent: Settings.data.appLauncher.iconMode === "tabler" && modelData.isTablerIcon ? gridTablerIconComponent : gridSystemIconComponent

          Component {
            id: gridTablerIconComponent
            NIcon {
              icon: modelData.icon
              pointSize: Style.fontSizeXXXL
              visible: modelData.icon && !modelData.displayString
              color: (gridEntryContainer.isSelected && !Settings.data.appLauncher.showIconBackground) ? Color.mOnPrimaryContainer : Color.mOnSurface
            }
          }

          Component {
            id: gridSystemIconComponent
            IconImage {
              anchors.fill: parent
              source: modelData.icon ? ThemeIcons.iconFromName(modelData.icon, "application-x-executable") : ""
              visible: modelData.icon && source !== "" && !modelData.displayString
              asynchronous: true
            }
          }
        }

        // String display
        NText {
          id: gridStringDisplay
          anchors.centerIn: parent
          visible: !!modelData.displayString || (!gridImagePreview.visible && !gridIconLoader.visible)
          text: modelData.displayString ? modelData.displayString : (modelData.name ? modelData.name.charAt(0).toUpperCase() : "?")
          pointSize: {
            if (modelData.displayString) {
              // Use custom size if provided, otherwise default scaling
              if (modelData.displayStringSize) {
                return modelData.displayStringSize * Style.uiScaleRatio;
              }
              if (launcher.providerHasDisplayString) {
                // Scale with cell width but cap at reasonable maximum
                const cellBasedSize = gridEntry.width * 0.4;
                const maxSize = Style.fontSizeXXXL * Style.uiScaleRatio;
                return Math.min(cellBasedSize, maxSize);
              }
              return Style.fontSizeXXL * 2 * Style.uiScaleRatio;
            }
            // Scale font size relative to cell width for low res, but cap at maximum
            const cellBasedSize = gridEntry.width * 0.25;
            const baseSize = Style.fontSizeXL * Style.uiScaleRatio;
            const maxSize = Style.fontSizeXXL * Style.uiScaleRatio;
            return Math.min(Math.max(cellBasedSize, baseSize), maxSize);
          }
          font.weight: Style.fontWeightBold
          color: modelData.displayString ? Color.mOnSurface : (gridEntryContainer.isSelected ? Color.mOnPrimaryContainer : Color.mOnSurface)
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

      // Text content (hidden when hideLabel is true)
      NText {
        visible: !modelData.hideLabel
        text: modelData.name || "Unknown"
        pointSize: {
          if (launcher.providerHasDisplayString && modelData.displayString) {
            return Style.fontSizeS * Style.uiScaleRatio;
          }
          // Scale font size relative to cell width for low res, but cap at maximum
          const cellBasedSize = gridEntry.width * 0.1;
          const baseSize = Style.fontSizeXS * Style.uiScaleRatio;
          const maxSize = Style.fontSizeS * Style.uiScaleRatio;
          return Math.min(Math.max(cellBasedSize, baseSize), maxSize);
        }
        font.weight: Style.fontWeightSemiBold
        color: gridEntryContainer.isSelected ? Color.mOnPrimaryContainer : Color.mOnSurface
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.maximumWidth: gridEntry.width - 8
        Layout.leftMargin: (launcher.providerHasDisplayString && modelData.displayString) ? Style.marginS : 0
        Layout.rightMargin: (launcher.providerHasDisplayString && modelData.displayString) ? Style.marginS : 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.NoWrap
        maximumLineCount: 1

        Behavior on color {
          ColorAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutQuint
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
        launcher.selectedIndex = gridEntryContainer.entryIndex;
    }
    onClicked: mouse => {
      launcher.selectedIndex = gridEntryContainer.entryIndex;
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
