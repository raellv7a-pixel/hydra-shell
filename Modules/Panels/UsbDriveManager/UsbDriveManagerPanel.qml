import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Hardware
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(430 * Style.uiScaleRatio)
  preferredHeight: Math.round(600 * Style.uiScaleRatio)
  panelBackgroundColor: HydraColor.mSurface
  panelBorderColor: Qt.alpha(HydraColor.mOutline, 0.28)

  onIsPanelOpenChanged: {
    if (isPanelOpen)
      UsbDriveService.refreshDevices();
  }

  panelContent: Item {
    id: panelContent

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M
        color: HydraColor.mSurfaceContainerHigh
        radius: Style.radiusL

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          Rectangle {
            Layout.preferredWidth: Style.baseWidgetSize * 0.8
            Layout.preferredHeight: Style.baseWidgetSize * 0.8
            radius: height / 2
            color: HydraColor.mPrimaryContainer

            NIcon {
              anchors.centerIn: parent
              icon: "usb"
              pointSize: Style.fontSizeL
              color: HydraColor.mPrimary
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
              Layout.fillWidth: true
              text: I18n.tr("usb-drive-manager.panel.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: HydraColor.mOnSurface
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("usb-drive-manager.panel.summary", {
                              "count": UsbDriveService.devices.length,
                              "mounted": UsbDriveService.mountedCount
                            })
              pointSize: Style.fontSizeXS
              color: HydraColor.mOnSurfaceVariant
            }
          }

          NIconButton {
            icon: "refresh"
            tooltipText: I18n.tr("usb-drive-manager.actions.refresh")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: !UsbDriveService.loading
            onClicked: UsbDriveService.refreshDevices()

            RotationAnimator on rotation {
              running: UsbDriveService.loading
              from: 0
              to: 360
              duration: 900
              loops: Animation.Infinite
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.close()
          }
        }
      }

      NBox {
        visible: UsbDriveService.dependenciesChecked && UsbDriveService.missingDependencies.length > 0
        Layout.fillWidth: true
        implicitHeight: dependencyRow.implicitHeight + Style.margin2M
        color: HydraColor.mErrorContainer
        radius: Style.radiusL

        RowLayout {
          id: dependencyRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NIcon {
            icon: "alert-triangle"
            color: HydraColor.mOnErrorContainer
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            NText {
              Layout.fillWidth: true
              text: I18n.tr("usb-drive-manager.errors.dependencies-title")
              font.weight: Style.fontWeightBold
              color: HydraColor.mOnErrorContainer
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("usb-drive-manager.errors.dependencies-description", {
                              "programs": UsbDriveService.missingDependencies.join(", ")
                            })
              pointSize: Style.fontSizeXS
              color: HydraColor.mOnErrorContainer
              wrapMode: Text.Wrap
            }
          }
        }
      }

      Item {
        visible: UsbDriveService.loading && UsbDriveService.devices.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.marginS

          NIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "refresh"
            pointSize: Style.fontSizeXXL
            color: HydraColor.mPrimary

            RotationAnimator on rotation {
              running: parent.parent.visible
              from: 0
              to: 360
              duration: 900
              loops: Animation.Infinite
            }
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: I18n.tr("usb-drive-manager.panel.loading")
            color: HydraColor.mOnSurfaceVariant
          }
        }
      }

      Item {
        visible: !UsbDriveService.loading && UsbDriveService.devices.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.marginS

          NIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "usb"
            pointSize: Style.fontSizeXXL
            color: HydraColor.mOnSurfaceVariant
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: UsbDriveService.lsblkAvailable ? I18n.tr("usb-drive-manager.panel.empty") : I18n.tr("usb-drive-manager.panel.unavailable")
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightMedium
            color: HydraColor.mOnSurface
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Math.round(300 * Style.uiScaleRatio)
            text: UsbDriveService.lsblkAvailable ? I18n.tr("usb-drive-manager.panel.empty-hint") : I18n.tr("usb-drive-manager.errors.missing-lsblk")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            pointSize: Style.fontSizeS
            color: HydraColor.mOnSurfaceVariant
          }
        }
      }

      ListView {
        visible: UsbDriveService.devices.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: UsbDriveService.devices
        spacing: Style.marginS
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: DeviceCard {
          required property var modelData
          width: ListView.view.width
          device: modelData
        }
      }

      NText {
        visible: UsbDriveService.actionRunning
        Layout.fillWidth: true
        text: I18n.tr("usb-drive-manager.panel.action-running")
        horizontalAlignment: Text.AlignHCenter
        pointSize: Style.fontSizeXS
        color: HydraColor.mPrimary
      }

      RowLayout {
        visible: UsbDriveService.devices.length > 0
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          Layout.fillWidth: true
          text: I18n.tr("usb-drive-manager.actions.unmount-all")
          icon: "plug-connected-x"
          enabled: UsbDriveService.mountedCount > 0 && !UsbDriveService.actionRunning && UsbDriveService.udisksctlAvailable
          onClicked: UsbDriveService.unmountAll()
        }

        NButton {
          Layout.fillWidth: true
          text: I18n.tr("usb-drive-manager.actions.eject-all")
          icon: "player-eject"
          enabled: !UsbDriveService.actionRunning && UsbDriveService.udisksctlAvailable
          onClicked: UsbDriveService.ejectAll()
        }
      }
    }
  }
}
