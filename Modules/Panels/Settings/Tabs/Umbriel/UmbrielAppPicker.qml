pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property string command: ""
  property string query: ""
  signal selected(string command)
  Layout.fillWidth: true
  spacing: Style.marginS

  readonly property var applications: (typeof DesktopEntries !== "undefined" ? DesktopEntries.applications.values : []) || []
  readonly property var selectedApp: applications.find(app => app && command === "gtk-launch " + app.id)
  readonly property var matches: {
    const text = query.trim().toLowerCase();
    if (!text)
      return [];
    return applications.filter(app => app && app.id && !app.hidden && !app.noDisplay &&
                               /^[a-zA-Z0-9._+-]+(?:\.desktop)?$/.test(app.id) &&
                               (app.name + " " + app.id + " " + (app.comment || "")).toLowerCase().includes(text))
                       .slice(0, 8);
  }

  NText { text: "Aplicativo: " + (root.selectedApp ? root.selectedApp.name : root.command || "Nenhum"); Layout.fillWidth: true; color: Color.mOnSurfaceVariant; wrapMode: Text.Wrap }
  NTextInput {
    Layout.fillWidth: true
    label: "Pesquisar aplicativo instalado"
    placeholderText: "Ex.: Dolphin, Nautilus, Thunar"
    onTextChanged: root.query = text
  }
  Repeater {
    model: root.matches
    delegate: Rectangle {
      id: appRow
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: Style.baseWidgetSize + Style.marginS
      radius: Style.radiusM
      color: hover.containsMouse ? Color.mSecondaryContainer : Color.mSurfaceContainerHigh
      border.color: activeFocus ? Color.mPrimary : Color.mOutline
      border.width: Style.borderS
      activeFocusOnTab: true
      Accessible.role: Accessible.Button
      Accessible.name: modelData.name + " · " + modelData.id
      Keys.onReturnPressed: root.selected("gtk-launch " + modelData.id)
      Keys.onSpacePressed: root.selected("gtk-launch " + modelData.id)
      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginM
        IconImage {
          Layout.preferredWidth: Style.baseWidgetSize * 0.65
          Layout.preferredHeight: Layout.preferredWidth
          source: ThemeIcons.iconFromName(appRow.modelData.icon || "application-x-executable")
          asynchronous: true
        }
        NText {
          Layout.fillWidth: true
          text: appRow.modelData.name + " · " + appRow.modelData.id
          elide: Text.ElideRight
          color: Color.mOnSurface
        }
      }
      MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selected("gtk-launch " + appRow.modelData.id)
      }
    }
  }
  NText {
    visible: root.query.trim() !== "" && root.matches.length === 0
    text: "Nenhum aplicativo instalado corresponde à busca. Use Executar comando para casos avançados."
    Layout.fillWidth: true
    wrapMode: Text.Wrap
    color: Color.mOnSurfaceVariant
  }
}
