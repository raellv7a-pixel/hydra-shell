import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

// One notification row shared by the compact NotificationsCard list and the
// expanded NotificationsDetailsCard list.
DashboardCard {
  id: notificationRow

  property var notificationData: ({})
  readonly property bool isExpanded: panelRoot.expandedNotificationId === notificationData.id
  readonly property var actionsList: panelRoot.parseNotificationActions(notificationData.actionsJson)
  readonly property bool canExpand: panelRoot.notificationCanExpand(notificationData)

  Layout.fillWidth: true
  Layout.preferredHeight: Math.max(Math.round(66 * panelRoot.panelUnit), contentColumn.implicitHeight + Style.marginS * 2)
  color: isExpanded ? panelRoot.m3SurfaceContainerHighest : panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusM
  border.color: isExpanded ? Qt.alpha(Color.mPrimary, 0.28) : "transparent"
  border.width: Style.borderS
  clip: true

  Behavior on Layout.preferredHeight {
    NumberAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  Behavior on color {
    ColorAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  Behavior on border.color {
    ColorAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  ColumnLayout {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: Style.marginS
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NImageRounded {
        Layout.preferredWidth: Math.round(42 * panelRoot.panelUnit)
        Layout.preferredHeight: Math.round(42 * panelRoot.panelUnit)
        Layout.alignment: Qt.AlignTop
        radius: Math.min(Style.radiusL, width / 2)
        imagePath: notificationData.cachedImage || notificationData.originalImage || ""
        fallbackIcon: "bell"
        fallbackIconSize: Style.fontSizeXL
        borderColor: Qt.alpha(Color.mOutline, 0.12)
        borderWidth: Style.borderS
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.marginXXS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          Rectangle {
            Layout.preferredWidth: Math.round(6 * panelRoot.panelUnit)
            Layout.preferredHeight: Math.round(6 * panelRoot.panelUnit)
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            visible: notificationData.urgency !== 1
            color: notificationData.urgency === 2 ? Color.mError : Color.mOnSurfaceVariant
          }

          NText {
            Layout.fillWidth: true
            text: notificationData.appName || "Unknown"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }

          NText {
            text: panelRoot.notificationTimeText(notificationData.timestamp)
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
            horizontalAlignment: Text.AlignRight
          }
        }

        NText {
          Layout.fillWidth: true
          text: notificationData.summary || notificationData.body || ""
          color: Color.mOnSurface
          textFormat: Text.StyledText
          wrapMode: isExpanded ? Text.WordWrap : Text.NoWrap
          maximumLineCount: isExpanded ? 3 : 1
          elide: Text.ElideRight
          pointSize: Style.fontSizeS
        }

        TapHandler {
          acceptedButtons: Qt.LeftButton
          onTapped: {
            if (notificationRow.isExpanded) {
              panelRoot.activateNotification(notificationData);
            } else if (notificationRow.canExpand) {
              panelRoot.expandedNotificationId = notificationData.id;
            } else {
              panelRoot.activateNotification(notificationData);
            }
          }
        }
      }

      NIconButton {
        icon: isExpanded ? "chevron-up" : "chevron-down"
        baseSize: Math.round(26 * panelRoot.panelUnit)
        tooltipText: isExpanded ? panelRoot.tr("collapseNotification") : panelRoot.tr("expandNotification")
        enabled: canExpand
        opacity: canExpand ? 1 : 0.35
        onClicked: panelRoot.expandedNotificationId = isExpanded ? "" : notificationData.id
      }

      NIconButton {
        icon: "x"
        baseSize: Math.round(26 * panelRoot.panelUnit)
        tooltipText: panelRoot.tr("removeNotification")
        onClicked: NotificationService.removeFromHistory(notificationData.id)
      }
    }

    NText {
      visible: isExpanded && String(notificationData.body || "").length > 0
      Layout.fillWidth: true
      text: notificationData.body || ""
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      textFormat: Text.StyledText
      wrapMode: Text.WordWrap
      maximumLineCount: 8
      onLinkActivated: link => Qt.openUrlExternally(link)
    }

    Flow {
      visible: isExpanded && actionsList.length > 0
      Layout.fillWidth: true
      spacing: Style.marginS

      Repeater {
        model: actionsList

        NButton {
          text: modelData.text || panelRoot.tr("notificationAction")
          icon: modelData.identifier === "default" ? "external-link" : ""
          fontSize: Style.fontSizeS
          implicitHeight: Math.round(26 * panelRoot.panelUnit)
          backgroundColor: Qt.alpha(Color.mPrimary, 0.16)
          textColor: Color.mOnSurface
          hoverColor: Color.mHover
          textHoverColor: Color.mOnHover
          onClicked: NotificationService.invokeAction(notificationData.id, modelData.identifier)
        }
      }
    }
  }
}
