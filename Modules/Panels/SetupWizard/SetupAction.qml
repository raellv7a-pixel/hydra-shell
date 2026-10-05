import QtQuick
import qs.Commons
import qs.Widgets

NButton {
  id: root
  activeFocusOnTab: enabled && visible
  Accessible.role: Accessible.Button
  Accessible.name: text
  Accessible.onPressAction: if (enabled) clicked()
  Keys.onSpacePressed: event => { if (enabled) clicked(); event.accepted = true; }
  Keys.onReturnPressed: event => { if (enabled) clicked(); event.accepted = true; }
  Keys.onEnterPressed: event => { if (enabled) clicked(); event.accepted = true; }

  Rectangle {
    anchors.fill: parent
    radius: root.buttonRadius
    color: "transparent"
    border.width: root.activeFocus ? Style.borderM : 0
    border.color: Color.mPrimary
  }
}
