import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Hardware
import qs.Widgets

NBox {
  id: root

  required property var device

  readonly property string displayName: {
    if (device.label && device.label !== device.name)
      return device.label;
    if (device.model)
      return device.model;
    return device.name || device.path;
  }
  readonly property string details: {
    var parts = [];
    if (device.size)
      parts.push(device.size);
    if (device.fstype)
      parts.push(String(device.fstype).toUpperCase());
    if (device.vendor && device.vendor !== device.model)
      parts.push(device.vendor);
    return parts.join(" · ");
  }

  implicitHeight: contentColumn.implicitHeight + Style.margin2M
  color: Color.mSurfaceContainer
  radius: Style.radiusL

  ColumnLayout {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      Rectangle {
        Layout.preferredWidth: Style.baseWidgetSize * 0.8
        Layout.preferredHeight: Style.baseWidgetSize * 0.8
        radius: height / 2
        color: root.device.isMounted ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh

        NIcon {
          anchors.centerIn: parent
          icon: "usb"
          pointSize: Style.fontSizeL
          color: root.device.isMounted ? Color.mPrimary : Color.mOnSurfaceVariant
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: root.displayName
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightMedium
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: root.details
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          elide: Text.ElideRight
        }
      }

      Rectangle {
        Layout.preferredWidth: statusText.implicitWidth + Style.margin2S
        Layout.preferredHeight: statusText.implicitHeight + Style.marginXS
        radius: height / 2
        color: root.device.isMounted ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh

        NText {
          id: statusText
          anchors.centerIn: parent
          text: root.device.isMounted ? I18n.tr("usb-drive-manager.device.mounted") : I18n.tr("usb-drive-manager.device.unmounted")
          pointSize: Style.fontSizeXXS
          font.weight: Style.fontWeightMedium
          color: root.device.isMounted ? Color.mOnPrimaryContainer : Color.mOnSurfaceVariant
        }
      }
    }

    NText {
      visible: root.device.isMounted
      Layout.fillWidth: true
      text: root.device.mountpoint
      pointSize: Style.fontSizeXS
      font.family: Settings.data.ui.fontFixed
      color: Color.mOnSurfaceVariant
      elide: Text.ElideMiddle
    }

    ColumnLayout {
      visible: root.device.isMounted
      Layout.fillWidth: true
      spacing: Style.marginXS

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(4, Math.round(4 * Style.uiScaleRatio))
        radius: height / 2
        color: Color.mSurfaceContainerHigh

        Rectangle {
          width: parent.width * Math.min(Math.max(root.device.usedPercent, 0), 100) / 100
          height: parent.height
          radius: parent.radius
          color: root.device.usedPercent >= 90 ? Color.mError : Color.mPrimary
        }
      }

      RowLayout {
        Layout.fillWidth: true

        NText {
          text: root.device.usedBytes > 0 ? I18n.tr("usb-drive-manager.device.used", {
                                                      "size": UsbDriveService.formatBytes(root.device.usedBytes)
                                                    }) : I18n.tr("usb-drive-manager.device.usage-loading")
          pointSize: Style.fontSizeXXS
          color: Color.mOnSurfaceVariant
        }

        Item {
          Layout.fillWidth: true
        }

        NText {
          text: root.device.freeBytes > 0 ? I18n.tr("usb-drive-manager.device.free", {
                                                      "size": UsbDriveService.formatBytes(root.device.freeBytes)
                                                    }) : ""
          pointSize: Style.fontSizeXXS
          color: Color.mOnSurfaceVariant
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NButton {
        visible: root.device.isMounted
        Layout.fillWidth: true
        text: I18n.tr("usb-drive-manager.actions.open")
        icon: "folder-open"
        enabled: !UsbDriveService.actionRunning
        onClicked: UsbDriveService.openInFileBrowser(root.device.mountpoint)
      }

      NButton {
        visible: !root.device.isMounted
        Layout.fillWidth: true
        text: I18n.tr("usb-drive-manager.actions.mount")
        icon: "plug-connected"
        enabled: !UsbDriveService.actionRunning && UsbDriveService.udisksctlAvailable
        onClicked: UsbDriveService.mountDevice(root.device.path, root.displayName)
      }

      NIconButton {
        visible: root.device.isMounted
        icon: "plug-connected-x"
        tooltipText: I18n.tr("usb-drive-manager.actions.unmount")
        baseSize: Style.baseWidgetSize * 0.8
        enabled: !UsbDriveService.actionRunning && UsbDriveService.udisksctlAvailable
        onClicked: UsbDriveService.unmountDevice(root.device.path, root.displayName)
      }

      NIconButton {
        icon: "player-eject"
        tooltipText: I18n.tr("usb-drive-manager.actions.eject")
        baseSize: Style.baseWidgetSize * 0.8
        enabled: !UsbDriveService.actionRunning && UsbDriveService.udisksctlAvailable
        onClicked: UsbDriveService.ejectDevice(root.device.path, root.device.parentPath, root.displayName)
      }
    }
  }
}
