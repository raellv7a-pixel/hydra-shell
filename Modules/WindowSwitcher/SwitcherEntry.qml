import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

Rectangle {
  id: root
  property var windowData: ({})
  property bool selected: false
  property bool vertical: false
  signal chosen
  radius: Style.iRadiusM
  color: selected ? Color.mPrimaryContainer : (mouse.containsMouse ? Color.mSurfaceContainerHighest : Color.mSurfaceContainerHigh)
  readonly property color textColor: selected ? Color.mOnPrimaryContainer : Color.mOnSurface
  readonly property var appEntry: ThemeIcons.findAppEntry(windowData.appId || "")
  readonly property string workspaceLabel: {
    const workspaces = CompositorService.workspaces;
    for (let i = 0; i < workspaces.count; i++) {
      const workspace = workspaces.get(i);
      if (workspace.id === windowData.workspaceId)
        return workspace.name + " · " + workspace.output;
    }
    return windowData.output || "";
  }
  GridLayout {
    anchors {
      fill: parent
      margins: Style.marginM
    }
    columns: root.vertical ? 1 : 2
    rowSpacing: Style.marginS
    columnSpacing: Style.marginL
    Item {
      visible: Settings.data.umbriel.windowSwitcher.showIcon
      Layout.rowSpan: root.vertical ? 1 : 2
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: (root.vertical ? 48 : 32) * Style.uiScaleRatio
      Layout.preferredHeight: Layout.preferredWidth
      IconImage {
        id: appIcon
        anchors.fill: parent
        source: ThemeIcons.iconForAppId(root.windowData.appId || "")
        visible: source.toString() !== "" && status !== Image.Error
      }
      NIcon {
        anchors.centerIn: parent
        visible: !appIcon.visible
        icon: "question-mark"
        pointSize: (root.vertical ? Style.fontSizeXXL : Style.fontSizeL)
        color: root.textColor
      }
    }
    NText {
      visible: Settings.data.umbriel.windowSwitcher.showTitle
      text: root.windowData.title || root.appEntry?.name || root.windowData.appId || "Janela"
      color: root.textColor
      font.weight: root.selected ? Style.fontWeightSemiBold : Style.fontWeightRegular
      Layout.fillWidth: true
      Layout.fillHeight: root.vertical
      horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
      wrapMode: root.vertical ? Text.Wrap : Text.NoWrap
      maximumLineCount: root.vertical ? 3 : 1
      elide: Text.ElideRight
    }
    NText {
      text: root.workspaceLabel
      color: root.selected ? Color.mOnPrimaryContainer : Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      Layout.fillWidth: true
      horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
      elide: Text.ElideRight
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.chosen()
  }
}
