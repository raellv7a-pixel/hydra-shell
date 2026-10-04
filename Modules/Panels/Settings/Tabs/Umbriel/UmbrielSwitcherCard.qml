import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  readonly property var options: Settings.data.umbriel.windowSwitcher
  spacing: Style.marginL
  Layout.fillWidth: true
  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("panels.umbriel.switcher-style")
    description: "Janelas com ícone, título e workspace; sem captura de imagem"
    model: [
      {
        key: "compact",
        name: "Compacto"
      },
      {
        key: "carousel",
        name: "Carrossel"
      }
    ]
    currentKey: root.options.style
    onSelected: key => root.options.style = key
  }
  NToggle {
    label: I18n.tr("panels.umbriel.switcher-mru")
    description: "Ordenar pelo histórico de foco da sessão"
    checked: root.options.mru
    onToggled: value => root.options.mru = value
  }
  NToggle {
    label: I18n.tr("panels.umbriel.switcher-workspace")
    checked: root.options.currentWorkspaceOnly
    onToggled: value => root.options.currentWorkspaceOnly = value
  }
  NToggle {
    label: I18n.tr("panels.umbriel.switcher-outputs")
    checked: root.options.showAllOutputs
    onToggled: value => root.options.showAllOutputs = value
  }
  NToggle {
    label: I18n.tr("panels.umbriel.switcher-title")
    checked: root.options.showTitle
    onToggled: value => root.options.showTitle = value
  }
  NToggle {
    label: I18n.tr("panels.umbriel.switcher-icon")
    checked: root.options.showIcon
    onToggled: value => root.options.showIcon = value
  }
  NToggle {
    label: I18n.tr("panels.umbriel.switcher-count")
    checked: root.options.showCount
    onToggled: value => root.options.showCount = value
  }
  NText {
    Layout.fillWidth: true
    text: "Alt+Tab avança · Shift+Alt+Tab volta · Soltar o modificador confirma. Atalhos pessoais existentes têm prioridade sobre os novos padrões."
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    wrapMode: Text.WordWrap
  }
}
