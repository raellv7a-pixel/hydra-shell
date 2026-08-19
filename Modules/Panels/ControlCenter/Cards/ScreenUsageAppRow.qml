import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
Item {
  id: screenUsageAppRow

  required property var panelRoot

  property var appData: null
  property int maxSeconds: 1

  Layout.preferredHeight: Math.round(34 * panelRoot.panelUnit)

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginXXS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "apps"
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }

      NText {
        Layout.fillWidth: true
        text: screenUsageAppRow.appData?.name || "--"
        color: Color.mOnSurface
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightMedium
        elide: Text.ElideRight
      }

      NText {
        text: panelRoot.durationText(screenUsageAppRow.appData?.seconds || 0)
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        font.family: Settings.data.ui.fontFixed
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(4, Math.round(5 * panelRoot.panelUnit))
      radius: height / 2
      color: Qt.alpha(Color.mSurface, 0.5)

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0.02, Math.min(1, Number(screenUsageAppRow.appData?.seconds || 0) / Math.max(1, screenUsageAppRow.maxSeconds)))
        radius: parent.radius
        color: Color.mPrimary
        opacity: 0.82
      }
    }
  }
}
