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
  panelBackgroundColor: Color.mSurface
  panelBorderColor: Qt.alpha(Color.mOutline, 0.28)

  onIsPanelOpenChanged: {
    if (isPanelOpen)
      UsbDriveService.refreshDevices();
  }

  panelContent: Item {
    id: panelContent

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.radiusPanel // must be >= the panel's own blob corner radius (28px), not paddingCard (16px), or content stops short and the wallpaper shows through the rounded-off corner
      spacing: Style.spaceS

      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.spaceS * 2
        color: Color.mSurfaceContainerHigh
        radius: Style.radiusCard

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.spaceS
          spacing: Style.spaceS

          Rectangle {
            Layout.preferredWidth: Style.baseWidgetSize * 0.8
            Layout.preferredHeight: Style.baseWidgetSize * 0.8
            radius: height / 2
            color: Color.mPrimaryContainer

            NIcon {
              anchors.centerIn: parent
              icon: "usb"
              pointSize: Style.fontSizeTitleSmall
              color: Color.mPrimary
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
              Layout.fillWidth: true
              text: I18n.tr("usb-drive-manager.panel.title")
              pointSize: Style.fontSizeTitleSmall
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("usb-drive-manager.panel.summary", {
                              "count": UsbDriveService.devices.length,
                              "mounted": UsbDriveService.mountedCount
                            })
              pointSize: Style.fontSizeLabelMedium
              color: Color.mOnSurfaceVariant
            }
          }

          NIconButton {
            icon: "refresh"
            tooltipText: I18n.tr("usb-drive-manager.actions.refresh")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: !UsbDriveService.loading
            onClicked: UsbDriveService.refreshDevices()

            RotationAnimator on rotation {
              running: UsbDriveService.loading && Style.motionEnabled
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
        implicitHeight: dependencyRow.implicitHeight + Style.spaceS * 2
        color: Color.mErrorContainer
        radius: Style.radiusCard

        RowLayout {
          id: dependencyRow
          anchors.fill: parent
          anchors.margins: Style.spaceS
          spacing: Style.spaceXS

          NIcon {
            icon: "alert-triangle"
            color: Color.mOnErrorContainer
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.spaceXXS

            NText {
              Layout.fillWidth: true
              text: I18n.tr("usb-drive-manager.errors.dependencies-title")
              font.weight: Style.fontWeightBold
              color: Color.mOnErrorContainer
            }

            NText {
              Layout.fillWidth: true
              text: I18n.tr("usb-drive-manager.errors.dependencies-description", {
                              "programs": UsbDriveService.missingDependencies.join(", ")
                            })
              pointSize: Style.fontSizeLabelMedium
              color: Color.mOnErrorContainer
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
          spacing: Style.spaceXS

          NIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "refresh"
            pointSize: Style.fontSizeTitleMedium
            color: Color.mPrimary

            RotationAnimator on rotation {
              running: parent.parent.visible && Style.motionEnabled
              from: 0
              to: 360
              duration: 900
              loops: Animation.Infinite
            }
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: I18n.tr("usb-drive-manager.panel.loading")
            color: Color.mOnSurfaceVariant
          }
        }
      }

      Item {
        visible: !UsbDriveService.loading && UsbDriveService.devices.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.spaceXS

          NIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "usb"
            pointSize: Style.fontSizeTitleMedium
            color: Color.mOnSurfaceVariant
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: UsbDriveService.lsblkAvailable ? I18n.tr("usb-drive-manager.panel.empty") : I18n.tr("usb-drive-manager.panel.unavailable")
            pointSize: Style.fontSizeBodySmall
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Math.round(300 * Style.uiScaleRatio)
            text: UsbDriveService.lsblkAvailable ? I18n.tr("usb-drive-manager.panel.empty-hint") : I18n.tr("usb-drive-manager.errors.missing-lsblk")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            pointSize: Style.fontSizeLabelMedium
            color: Color.mOnSurfaceVariant
          }
        }
      }

      ListView {
        visible: UsbDriveService.devices.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        model: UsbDriveService.devices
        spacing: Style.spaceXS
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
        pointSize: Style.fontSizeLabelSmall
        color: Color.mPrimary
      }

      RowLayout {
        visible: UsbDriveService.devices.length > 0
        Layout.fillWidth: true
        spacing: Style.spaceXS

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
