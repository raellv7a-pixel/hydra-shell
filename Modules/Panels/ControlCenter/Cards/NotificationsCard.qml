import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System
DashboardCard {
  id: notificationsCard

  styleKey: "notifications"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "left"
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("notifications")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: panelRoot.componentText("notifications", true)
        elide: Text.ElideRight
      }

      NIconButton {
        icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
        tooltipText: panelRoot.tr("dnd")
        baseSize: Math.round(30 * panelRoot.panelUnit)
        colorBgHover: panelRoot.componentButtonBackground("notifications")
        colorFg: panelRoot.componentText("notifications", true)
        colorFgHover: panelRoot.componentButtonText("notifications")
        colorBorderHover: panelRoot.componentButtonBackground("notifications")
        onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
      }

      NIconButton {
        icon: "trash"
        tooltipText: panelRoot.tr("clearNotifications")
        baseSize: Math.round(30 * panelRoot.panelUnit)
        enabled: NotificationService.historyModel.count > 0
        colorBgHover: panelRoot.componentButtonBackground("notifications")
        colorFg: panelRoot.componentText("notifications", true)
        colorFgHover: panelRoot.componentButtonText("notifications")
        colorBorderHover: panelRoot.componentButtonBackground("notifications")
        onClicked: NotificationService.clearHistory()
      }

      SubmoduleButton {
        panelRoot: notificationsCard.panelRoot
        targetView: "notifications"
        tooltipText: panelRoot.tr("details")
      }
    }

    NText {
      visible: NotificationService.historyModel.count === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      text: panelRoot.tr("noNotifications")
      color: panelRoot.componentText("notifications", false)
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: width
      contentHeight: notificationsColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: notificationsColumn
        width: parent.width
        spacing: Style.marginS

        Repeater {
          model: NotificationService.historyModel.count

          NotificationRow {
            panelRoot: notificationsCard.panelRoot
            Layout.fillWidth: true
            notificationData: NotificationService.historyModel.get(index)
          }
        }
      }
    }
  }
}
