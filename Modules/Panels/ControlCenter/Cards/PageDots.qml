import QtQuick
import qs.Commons

// Small paged-content indicator (dots row) used by the disk pager and the
// compact calendar/screen-usage/timer swipe pages.
Row {
  id: pageDots

  required property var panelRoot

  property int count: 0
  property int currentIndex: 0
  signal selected(int index)

  spacing: Math.round(5 * panelRoot.panelUnit)
  visible: count > 1

  Repeater {
    model: pageDots.count

    Rectangle {
      width: Math.round((index === pageDots.currentIndex ? 16 : 6) * panelRoot.panelUnit)
      height: Math.round(6 * panelRoot.panelUnit)
      radius: height / 2
      color: index === pageDots.currentIndex ? Color.mPrimary : Qt.alpha(Color.mOnSurfaceVariant, 0.36)

      Behavior on width {
        NumberAnimation {
          duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
          easing.type: Easing.OutCubic
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: pageDots.selected(index)
      }
    }
  }
}
