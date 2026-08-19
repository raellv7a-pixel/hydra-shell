import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
// Square capture-tool button used by RecordingCard's GIF/MP4/screenshot grid.
DashboardCard {
  id: toolkitButton

  styleKey: panelRoot.inheritedStyleKey(parent)

  property string labelText: ""
  property string iconName: ""
  property bool active: false
  property bool destructive: false
  signal triggered

  Layout.fillWidth: true
  Layout.preferredHeight: Math.round(32 * panelRoot.panelUnit)
  color: destructive ? Qt.alpha(Color.mError, 0.14) : (active ? panelRoot.m3PrimaryContainer : panelRoot.componentColor(styleKey, "buttonBackground", panelRoot.m3SurfaceContainerHigh))
  radius: height / 2
  border.color: activeFocus ? (destructive ? Color.mError : panelRoot.componentAccent(styleKey)) : "transparent"
  border.width: activeFocus ? Style.borderM : 0
  scale: mouseArea.pressed ? 0.96 : (mouseArea.containsMouse || activeFocus ? 1.02 : 1)
  transformOrigin: Item.Center
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: labelText

  Behavior on border.color {
    ColorAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
      easing.type: Easing.OutCubic
    }
  }

  Behavior on scale {
    ScaleAnimator {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
      easing.type: mouseArea.pressed ? Easing.OutCubic : Easing.OutBack
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.marginS
    spacing: Style.marginS

    NIcon {
      icon: iconName
      pointSize: Style.fontSizeM
      color: destructive ? Color.mError : panelRoot.componentAccent(toolkitButton.styleKey)
    }

    NText {
      Layout.fillWidth: true
      text: labelText
      color: panelRoot.componentText(toolkitButton.styleKey, true)
      pointSize: Style.fontSizeS
      font.weight: Style.fontWeightSemiBold
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: toolkitButton.triggered()
  }

  Keys.onReturnPressed: toolkitButton.triggered()
  Keys.onSpacePressed: toolkitButton.triggered()
}
