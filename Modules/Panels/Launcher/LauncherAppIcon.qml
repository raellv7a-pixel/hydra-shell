import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Widgets

Item {
  id: root
  property string appIcon: ""
  readonly property string iconSource: Quickshell.iconPath(appIcon || "application-x-executable", true)
  IconImage {
    anchors.fill: parent
    source: root.iconSource
    visible: root.iconSource !== ""
    asynchronous: true
  }
  NIcon {
    anchors.fill: parent
    visible: root.iconSource === ""
    icon: "apps"
    color: Color.mOnSurfaceVariant
    pointSize: root.height * 0.6 / Style.uiScaleRatio
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
