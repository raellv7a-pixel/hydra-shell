import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Compositor
import qs.Services.Hardware
import qs.Widgets

SmartPanel {
  id: root
  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(550 * Style.uiScaleRatio)
  readonly property bool controlsAvailable: CompositorService.screencastCapability === "changeable"
  panelContent: ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM
    NText { text: "Compartilhamento"; pointSize: Style.fontSizeXL; font.weight: Style.fontWeightSemiBold }
    NText {
      Layout.fillWidth: true
      text: PrivacyIndicatorService.scrActive ? "Captura de tela detectada no PipeWire" : "Nenhuma captura de tela detectada no PipeWire"
      wrapMode: Text.WordWrap
    }
    NText { Layout.fillWidth: true; visible: PrivacyIndicatorService.scrApps.length > 0; text: PrivacyIndicatorService.scrApps.join(", "); color: Color.mOnSurfaceVariant; wrapMode: Text.WordWrap }
    NText {
      Layout.fillWidth: true
      text: CompositorService.screencastCommand.serial > 0 ? "Último comando Umbriel: " + ({manual: "fonte manual", "follow-window": "seguir janela", "follow-output": "seguir monitor", cleared: "pausar transmissão"}[CompositorService.screencastCommand.mode] || "desconhecido") + (CompositorService.screencastTargetLabel ? " · " + CompositorService.screencastTargetLabel : "") : "A Umbriel ainda não informou um comando de compartilhamento."
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }
    NText {
      Layout.fillWidth: true
      visible: !root.controlsAvailable
      text: "Este backend não informa se a sessão permite trocar a fonte. Os controles ficam indisponíveis; use os atalhos nativos da Umbriel."
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      pointSize: Style.fontSizeS
    }
    NButton { Layout.fillWidth: true; text: "Compartilhar janela focada"; enabled: root.controlsAvailable; onClicked: CompositorService.screencastSetWindow("") }
    NButton { Layout.fillWidth: true; text: "Compartilhar monitor focado"; enabled: root.controlsAvailable; onClicked: CompositorService.screencastSetOutput("") }
    NText { Layout.fillWidth: true; text: "Ao seguir janelas, trocar o foco também compartilha a outra janela. Use apenas se todas forem seguras para compartilhar."; wrapMode: Text.WordWrap; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeS }
    NButton { Layout.fillWidth: true; text: "Seguir janela focada"; enabled: root.controlsAvailable; onClicked: CompositorService.screencastFollowWindow() }
    NButton { Layout.fillWidth: true; text: "Seguir monitor focado"; enabled: root.controlsAvailable; onClicked: CompositorService.screencastFollowOutput() }
    NButton { Layout.fillWidth: true; text: "Fixar alvo atual"; enabled: root.controlsAvailable; onClicked: CompositorService.screencastFollowStop() }
    NButton { Layout.fillWidth: true; text: "Pausar transmissão"; enabled: root.controlsAvailable; onClicked: CompositorService.screencastPause() }
    Item { Layout.fillHeight: true }
  }
}
