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

  Repeater {
    model: root.groups
    delegate: Rectangle {
      id: chip
      required property var modelData
      readonly property bool selected: !!root.expandedGroups[modelData.key]
      width: chipContent.implicitWidth + Style.margin2M
      height: Style.baseWidgetSize
      radius: height / 2
      color: selected ? Color.mSecondaryContainer : chipHover.containsMouse ? Color.mSurfaceContainerHigh : Color.mSurfaceContainerLow
      border.color: activeFocus ? Color.mPrimary : "transparent"
      border.width: activeFocus ? Style.borderM : 0
      activeFocusOnTab: true
      Accessible.role: Accessible.Button
      Accessible.name: modelData.title
      Accessible.description: selected ? "Grupo aberto" : "Abrir grupo"
      Keys.onReturnPressed: root.groupSelected(modelData.key)
      Keys.onSpacePressed: root.groupSelected(modelData.key)
      Behavior on color { ColorAnimation { duration: Style.animationFast } }
      RowLayout {
        id: chipContent
        anchors.centerIn: parent
        spacing: Style.marginXS
        NIcon { icon: chip.modelData.icon; pointSize: Style.fontSizeM; color: chip.selected ? Color.mOnSecondaryContainer : Color.mOnSurface }
        NText { text: chip.modelData.title; pointSize: Style.fontSizeS; color: chip.selected ? Color.mOnSecondaryContainer : Color.mOnSurface }
      }
      MouseArea {
        id: chipHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.groupSelected(chip.modelData.key)
      }
    }
  }
}
