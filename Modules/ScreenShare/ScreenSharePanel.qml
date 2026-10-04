import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root
  preferredWidth: Math.round(720 * Style.uiScaleRatio)
  preferredHeight: Math.round(540 * Style.uiScaleRatio)
  panelAnchorLeft: isFramed
  panelAnchorHorizontalCenter: !isFramed
  panelAnchorVerticalCenter: true
  property string sourceKind: "monitor"
  function onEscapePressed() { ScreenShareService.cancel(); }
  onClosed: { if (ScreenShareService.panel === root) ScreenShareService.cancel(); }
  Component.onDestruction: { if (ScreenShareService.panel === root) ScreenShareService.reset(); }
  onOpened: {
    sourceKind = ScreenShareService.request?.types.includes("monitor") ? "monitor" : "window";
    contentItem?.forceActiveFocus();
  }
  panelContent: FocusScope {
    id: content
    focus: true
    readonly property var request: ScreenShareService.request
    readonly property var sources: root.sourceKind === "monitor" ? (request?.outputs || []) : (request?.windows || [])
    Keys.onEscapePressed: ScreenShareService.cancel()
    Keys.onReturnPressed: { if (ScreenShareService.selections.length) ScreenShareService.respond(ScreenShareService.selections); }
    Keys.onEnterPressed: { if (ScreenShareService.selections.length) ScreenShareService.respond(ScreenShareService.selections); }
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM
      NText { text: "Compartilhar tela"; pointSize: Style.fontSizeXL; font.weight: Style.fontWeightSemiBold }
      NText {
        Layout.fillWidth: true
        text: content.request?.multiple ? "Escolha uma ou mais fontes para compartilhar." : "Escolha um monitor ou uma janela para compartilhar."
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
      }
      Flow {
        Layout.fillWidth: true
        spacing: Style.marginS
        Repeater {
          model: content.request?.types || []
          NButton {
            required property string modelData
            text: modelData === "monitor" ? "Monitores" : "Janelas"
            backgroundColor: root.sourceKind === modelData ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh
            textColor: root.sourceKind === modelData ? Color.mOnPrimaryContainer : Color.mOnSurface
            activeFocusOnTab: true
            Keys.onSpacePressed: clicked()
            onClicked: { root.sourceKind = modelData; grid.currentIndex = 0; }
          }
        }
      }
      GridView {
        id: grid
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: content.sources
        cellWidth: width / Math.max(1, Math.floor(width / (210 * Style.uiScaleRatio)))
        cellHeight: Math.round(170 * Style.uiScaleRatio)
        currentIndex: 0
        focus: true
        activeFocusOnTab: true
        keyNavigationEnabled: true
        ScrollBar.vertical: ScrollBar {}
        Keys.onSpacePressed: {
          const row = content.sources[currentIndex];
          if (row) ScreenShareService.toggle(root.sourceKind, row.name || row.identifier);
        }
        delegate: Item {
          required property var modelData
          required property int index
          width: grid.cellWidth
          height: grid.cellHeight
          readonly property string value: modelData.name || modelData.identifier
          readonly property bool selected: ScreenShareService.selected(root.sourceKind, value)
          Rectangle {
            anchors.fill: parent
            anchors.margins: Style.marginXS
            radius: Style.radiusM
            color: parent.selected ? Color.mPrimaryContainer : (pointer.containsMouse ? Color.mSurfaceContainerHigh : Color.mSurfaceContainerLow)
            border.width: grid.activeFocus && grid.currentIndex === index ? Style.borderM : 0
            border.color: Color.mPrimary
            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS
              RowLayout {
                Layout.fillWidth: true
                NImageRounded {
                  visible: root.sourceKind === "window"
                  Layout.preferredWidth: Style.fontSizeXXXL * 1.5
                  Layout.preferredHeight: Layout.preferredWidth
                  imagePath: ThemeIcons.iconForAppId(modelData.app_id || "")
                  fallbackIcon: "app-window"
                  borderWidth: 0
                }
                NIcon { visible: root.sourceKind === "monitor"; icon: "device-desktop"; pointSize: Style.fontSizeXXXL; color: Color.mOnSurfaceVariant }
                Item { Layout.fillWidth: true }
                NIcon { visible: selected; icon: "check"; color: Color.mPrimary }
              }
              NText { Layout.fillWidth: true; text: modelData.title || modelData.name || modelData.app_id || "Janela"; elide: Text.ElideRight; font.weight: Style.fontWeightSemiBold }
              NText {
                Layout.fillWidth: true
                text: root.sourceKind === "monitor" ? modelData.width + " × " + modelData.height + " · " + (modelData.description || modelData.name) : (modelData.app_id || "Aplicativo sem identificador")
                elide: Text.ElideRight
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
              }
            }
            MouseArea {
              id: pointer
              anchors.fill: parent
              hoverEnabled: true
              onClicked: { grid.currentIndex = index; grid.forceActiveFocus(); ScreenShareService.toggle(root.sourceKind, value); }
            }
          }
        }
        NText { anchors.centerIn: parent; visible: grid.count === 0; text: content.request ? "Nenhuma fonte disponível nesta categoria." : "Carregando fontes…"; color: Color.mOnSurfaceVariant }
      }
      RowLayout {
        Layout.fillWidth: true
        NText { text: ScreenShareService.selections.length + " selecionada(s)"; color: Color.mOnSurfaceVariant }
        Item { Layout.fillWidth: true }
        NButton { text: "Cancelar"; backgroundColor: Color.mSurfaceContainerHigh; textColor: Color.mOnSurface; activeFocusOnTab: true; Keys.onSpacePressed: clicked(); onClicked: ScreenShareService.cancel() }
        NButton { text: "Compartilhar"; enabled: ScreenShareService.selections.length > 0; activeFocusOnTab: true; Keys.onSpacePressed: clicked(); onClicked: ScreenShareService.respond(ScreenShareService.selections) }
      }
    }
  }
}
