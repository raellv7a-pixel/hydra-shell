import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
  spacing: Style.marginL
  Layout.fillWidth: true
  NToggle {
    label: I18n.tr("panels.umbriel.type-to-launch")
    description: I18n.tr("panels.umbriel.type-to-launch-description")
    checked: Settings.data.umbriel.typeToLaunch
    onToggled: value => Settings.data.umbriel.typeToLaunch = value
  }
  NText {
    Layout.fillWidth: true
    text: UmbrielSettingsStore.error
      ? "Captura suspensa: " + UmbrielSettingsStore.error
      : UmbrielSettingsStore.dirty
        ? "Salve ou reverta as alterações nativas antes de digitar na Overview. O draft não é descartado ao entrar nela."
        : (!UmbrielSettingsStore.loaded || UmbrielSettingsStore.busy)
          ? "Verificando a configuração nativa; a captura permanece suspensa até concluir."
          : UmbrielSettingsStore.externallyOwned
            ? "A captura está suspensa: a configuração da Overview pertence a um arquivo externo. Configure os atalhos nativos no arquivo proprietário."
            : (UmbrielSettingsStore.committed.overview?.shortcuts ?? true)
              ? "Os atalhos nativos da Visão Geral têm prioridade. Desative ‘Atalhos de janelas’ no grupo Visão Geral e salve para permitir digitar para pesquisar. Nenhuma preferência é alterada automaticamente."
              : "Disponível com os atalhos nativos de janelas desativados. O Lançador aberto pela Visão Geral fecha junto com ela; o Lançador normal mantém seu comportamento."
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
    pointSize: Style.fontSizeS
  }
  NToggle {
    label: I18n.tr("panels.umbriel.submap-indicator")
    description: I18n.tr("panels.umbriel.submap-indicator-description")
    checked: Settings.data.umbriel.showSubmapIndicator
    onToggled: value => Settings.data.umbriel.showSubmapIndicator = value
  }
}
