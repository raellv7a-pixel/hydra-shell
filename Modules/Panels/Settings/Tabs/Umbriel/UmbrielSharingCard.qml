import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  Layout.fillWidth: true
  spacing: Style.marginM
  Component.onCompleted: PortalPickerSettingsStore.refresh()
  NToggle {
    Layout.fillWidth: true
    label: "Usar seletor da Hydra"
    description: "Integra a seleção à moldura. Se a Hydra falhar, usa o seletor oficial da Umbriel. O seletor anterior será preservado."
    checked: PortalPickerSettingsStore.enabled
    enabled: PortalPickerSettingsStore.loaded && !PortalPickerSettingsStore.busy && !PortalPickerSettingsStore.externallyChanged
    onToggled: checked => PortalPickerSettingsStore.setEnabled(checked)
  }
  NText {
    Layout.fillWidth: true
    visible: PortalPickerSettingsStore.externallyChanged
    text: "O seletor foi alterado externamente. A Hydra não substituirá essa configuração: " + PortalPickerSettingsStore.chooser
    color: Color.mError
    wrapMode: Text.WordWrap
  }
  NText { Layout.fillWidth: true; visible: PortalPickerSettingsStore.error !== ""; text: PortalPickerSettingsStore.error; color: Color.mError; wrapMode: Text.WordWrap }
  NToggle {
    Layout.fillWidth: true
    label: "Mostrar controles de compartilhamento no indicador"
    description: "Abre o painel pelo indicador de privacidade. Trocas de fonte exigem capability comprovada pelo backend."
    checked: Settings.data.umbriel.showSharingControls
    onToggled: checked => Settings.data.umbriel.showSharingControls = checked
  }
  NToggle {
    Layout.fillWidth: true
    label: "Confirmar antes de trocar a fonte"
    description: "Mantém a proteção nativa na primeira troca dinâmica durante o compartilhamento."
    checked: !(UmbrielSettingsStore.draft.screencast?.disable_dynamic_confirmation ?? false)
    enabled: UmbrielSettingsStore.loaded && !UmbrielSettingsStore.busy && !UmbrielSettingsStore.externallyOwned
    onToggled: checked => UmbrielSettingsStore.updateSharingConfirmation(checked)
  }
  NButton { text: "Recarregar configuração do portal"; enabled: !PortalPickerSettingsStore.busy; onClicked: PortalPickerSettingsStore.refresh() }
}
