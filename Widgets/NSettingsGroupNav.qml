pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Flow {
  id: root
  property var groups: []
  property var expandedGroups: ({})
  signal groupSelected(string key)

  Layout.fillWidth: true
  spacing: Style.marginS

  function focusGroup(index) {
    const chip = chips.itemAt(index);
    if (chip)
      chip.forceActiveFocus(Qt.TabFocusReason);
  }

  Repeater {
    id: chips
    model: root.groups
    delegate: NStateLayer {
      id: chip
      required property var modelData
      required property int index
      readonly property bool selected: !!root.expandedGroups[modelData.key]
      width: Math.min(root.width, chipContent.implicitWidth + Style.margin2L)
      height: Math.max(Style.baseWidgetSize * Style.uiScaleRatio, chipContent.implicitHeight + Style.margin2S)
      radius: height / 2
      baseColor: selected ? HydraColor.mSecondaryContainer : HydraColor.mSurfaceContainerLow
      stateColor: selected ? HydraColor.mOnSecondaryContainer : HydraColor.mOnSurface
      hovering: chipHover.containsMouse
      pressed: chipHover.pressed
      focusPolicy: Qt.StrongFocus
      Accessible.role: Accessible.Button
      Accessible.name: modelData.title
      Accessible.checkable: true
      Accessible.checked: selected
      Accessible.onPressAction: root.groupSelected(modelData.key)
      Keys.onReturnPressed: root.groupSelected(modelData.key)
      Keys.onSpacePressed: root.groupSelected(modelData.key)
      Keys.onEnterPressed: root.groupSelected(modelData.key)
      Keys.onLeftPressed: root.focusGroup(Math.max(0, index - 1))
      Keys.onRightPressed: root.focusGroup(Math.min(chips.count - 1, index + 1))
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
          root.focusGroup(0);
          event.accepted = true;
        } else if (event.key === Qt.Key_End) {
          root.focusGroup(chips.count - 1);
          event.accepted = true;
        }
      }
      RowLayout {
        id: chipContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.marginL
        anchors.rightMargin: Style.marginL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.marginXS
        NIcon {
          icon: chip.modelData.icon
          pointSize: Style.fontSizeS
          color: chip.selected ? HydraColor.mOnSecondaryContainer : HydraColor.mOnSurfaceVariant
          Accessible.ignored: true
        }
        NText {
          Layout.fillWidth: true
          text: chip.modelData.title
          pointSize: Style.fontSizeS
          color: chip.selected ? HydraColor.mOnSecondaryContainer : HydraColor.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          elide: Text.ElideNone
          Accessible.ignored: true
        }
      }
      MouseArea {
        id: chipHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          chip.forceActiveFocus(Qt.MouseFocusReason);
          root.groupSelected(chip.modelData.key);
        }
      }
    }
  }
}
