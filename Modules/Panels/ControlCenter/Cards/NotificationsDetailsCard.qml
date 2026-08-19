import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System
DashboardCard {
  id: notificationsDetailsCard

  styleKey: "notifications"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "right"
  clip: true

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * panelRoot.panelUnit)
        tooltipText: panelRoot.tr("back")
        onClicked: panelRoot.activeDetailView = ""
      }

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("notifications")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NText {
        text: NotificationService.historyModel.count
        pointSize: Style.fontSizeS
        font.family: Settings.data.ui.fontFixed
        color: NotificationService.historyModel.count > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      DashboardCard {
        panelRoot: notificationsDetailsCard.panelRoot
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(72 * panelRoot.panelUnit)
        color: panelRoot.m3SurfaceContainerHigh
        radius: Style.radiusS

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          Item {
            Layout.preferredWidth: Math.round(24 * panelRoot.panelUnit)
            Layout.fillHeight: true

            NIcon {
              anchors.centerIn: parent
              icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
              pointSize: Style.fontSizeL
              color: NotificationService.doNotDisturb ? Color.mError : Color.mPrimary
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Style.marginXXS

            NText {
              Layout.fillWidth: true
              text: panelRoot.tr("dnd")
              color: Color.mOnSurface
              font.weight: Style.fontWeightSemiBold
              elide: Text.ElideRight
            }

            NText {
              text: NotificationService.doNotDisturb ? panelRoot.tr("enabled") : panelRoot.tr("disabled")
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
            }
          }

          NIconButton {
            icon: NotificationService.doNotDisturb ? "toggle-right" : "toggle-left"
            baseSize: Math.round(30 * panelRoot.panelUnit)
            onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
          }
        }
      }

      DashboardCard {
        panelRoot: notificationsDetailsCard.panelRoot
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(72 * panelRoot.panelUnit)
        color: panelRoot.m3SurfaceContainerHigh
        radius: Style.radiusS

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "trash"
            pointSize: Style.fontSizeXL
            color: NotificationService.historyModel.count > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              text: panelRoot.tr("clear")
              color: Color.mOnSurface
              font.weight: Style.fontWeightSemiBold
              elide: Text.ElideRight
            }

            NText {
              text: panelRoot.tr("openHistory")
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
            }
          }

          NIconButton {
            icon: "x"
            baseSize: Math.round(30 * panelRoot.panelUnit)
            enabled: NotificationService.historyModel.count > 0
            onClicked: NotificationService.clearHistory()
          }
        }
      }
    }

    DashboardCard {
      panelRoot: notificationsDetailsCard.panelRoot
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: panelRoot.m3SurfaceContainerHigh
      radius: Style.radiusS

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            text: panelRoot.tr("openHistory")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }

          NText {
            text: NotificationService.historyModel.count
            color: Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
          }
        }

        NText {
          visible: NotificationService.historyModel.count === 0
          Layout.fillWidth: true
          Layout.fillHeight: true
          text: panelRoot.tr("noNotifications")
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Flickable {
          visible: NotificationService.historyModel.count > 0
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: notificationDetailsColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: notificationDetailsColumn
            width: parent.width
            spacing: Style.marginS

            Repeater {
              model: NotificationService.historyModel

              ColumnLayout {
                // Plain wrapper: Repeater doesn't reliably inject the `index`
                // context property into a delegate whose root type has other
                // required properties (NotificationRow requires panelRoot via
                // DashboardCard). Keeping index/model resolution in this
                // wrapper's own scope and forwarding it explicitly avoids that.
                Layout.fillWidth: true

                NotificationRow {
                  panelRoot: notificationsDetailsCard.panelRoot
                  Layout.fillWidth: true
                  notificationData: NotificationService.historyModel.get(index)
                }
              }
            }
          }
        }
      }
    }
  }
}
