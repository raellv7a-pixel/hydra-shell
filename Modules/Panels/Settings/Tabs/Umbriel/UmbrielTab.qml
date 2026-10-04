import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  property var scrollView: null
  readonly property var settingsStore: UmbrielSettingsStore
  readonly property var groups: [
    { key: "keybinds", title: "Atalhos", icon: "keyboard" },
    { key: "overview", title: "Visão Geral", icon: "layout-dashboard" },
    { key: "switcher", title: "Alternador de Janelas", icon: "layout-dashboard" },
    { key: "interaction", title: "Interação Hydra", icon: "keyboard" },
    { key: "corners", title: "Cantos Ativos", icon: "focus-2" }
  ]
  readonly property var expandedGroups: SettingsPanelService.umbrielGroupState
  Layout.fillWidth: true
  spacing: Style.marginL

  Component.onCompleted: {
    if (!settingsStore.loaded || !settingsStore.dirty)
      settingsStore.refresh();
  }
  Timer {
    id: jumpTimer
    property string key: ""
    interval: Style.animationNormal + 40
    onTriggered: root.scrollTo(key)
  }

  function showOnly(key) {
    SettingsPanelService.umbrielGroupState = {
      keybinds: key === "keybinds",
      overview: key === "overview",
      switcher: key === "switcher",
      interaction: key === "interaction",
      corners: key === "corners"
    };
  }

  function toggle(key, open) {
    SettingsPanelService.umbrielGroupState = Object.assign({}, expandedGroups, { [key]: open });
  }
  function jump(key) {
    showOnly(key);
    jumpTimer.key = key;
    jumpTimer.restart();
  }
  function scrollTo(key) {
    if (!root.scrollView) return;
    const flick = root.scrollView.contentItem;
    const card = {keybinds: keybindsGroup, overview: overviewGroup, switcher: switcherGroup,
      interaction: interactionGroup, corners: cornersGroup}[key];
    const y = card.mapToItem(flick.contentItem, 0, 0).y;
    flick.contentY = Math.max(0, Math.min(y, flick.contentHeight - flick.height));
  }
  function revealSettingsGroup(key) {
    if (expandedGroups.hasOwnProperty(key))
      showOnly(key);
  }
  function navigateToSettingsGroup(index) {
    if (index >= 0 && index < groups.length) jump(groups[index].key);
  }

  NText {
    text: "Integração nativa com a Umbriel · atalhos, visão geral e cantos ativos."
    color: Color.mOnSurfaceVariant
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
  NSettingsGroupNav {
    groups: root.groups
    expandedGroups: root.expandedGroups
    onGroupSelected: key => root.jump(key)
  }
  NText {
    visible: root.settingsStore.error !== ""
    text: root.settingsStore.error
    color: Color.mError
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
  NText {
    visible: root.settingsStore.externallyOwned
    text: "Configuração controlada externamente: " + root.settingsStore.owners.join(", ") + ". O config.toml e includes pessoais podem prevalecer; a Hydra não editará essas seções."
    color: Color.mError
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }
  ColumnLayout {
    Layout.fillWidth: true
    visible: root.settingsStore.dirty || root.settingsStore.busy
    spacing: Style.marginS
    NText {
      Layout.fillWidth: true
      text: "Alterações Umbriel não salvas"
      color: Color.mOnSurfaceVariant
    }
    RowLayout {
      Layout.fillWidth: true
      Item { Layout.fillWidth: true }
      NButton {
        text: "Reverter"
        backgroundColor: Color.mSurfaceContainerHigh
        textColor: Color.mOnSurfaceVariant
        enabled: root.settingsStore.dirty && !root.settingsStore.busy
        onClicked: root.settingsStore.revert()
      }
      NButton {
        text: root.settingsStore.busy ? "Validando…" : "Salvar alterações"
        enabled: root.settingsStore.loaded && root.settingsStore.dirty && !root.settingsStore.busy && !root.settingsStore.externallyOwned
        onClicked: root.settingsStore.save()
      }
    }
  }
  NSettingsGroupCard {
    id: keybindsGroup
    title: "Atalhos"
    description: "Combinações, ações e comportamento dos atalhos"
    icon: "keyboard"
    expanded: root.expandedGroups.keybinds
    onToggled: open => root.toggle("keybinds", open)
    UmbrielKeybindsCard { Layout.fillWidth: true }
  }
  NSettingsGroupCard {
    id: overviewGroup
    title: "Visão Geral"
    description: "Pré-visualizações de workspaces, gestos e atalhos"
    icon: "layout-dashboard"
    expanded: root.expandedGroups.overview
    onToggled: open => root.toggle("overview", open)
    UmbrielOverviewCard { Layout.fillWidth: true }
  }
  NSettingsGroupCard {
    id: switcherGroup
    title: "Alternador de Janelas"
    description: "Apresentação, histórico de foco e filtros do Alt+Tab"
    icon: "layout-dashboard"
    expanded: root.expandedGroups.switcher ?? false
    onToggled: open => root.toggle("switcher", open)
    UmbrielSwitcherCard { Layout.fillWidth: true }
  }
  NSettingsGroupCard {
    id: interactionGroup
    title: "Interação Hydra"
    description: "Digitação na Overview e feedback de modos do teclado"
    icon: "keyboard"
    expanded: root.expandedGroups.interaction ?? false
    onToggled: open => root.toggle("interaction", open)
    UmbrielInteractionCard { Layout.fillWidth: true }
  }
  NSettingsGroupCard {
    id: cornersGroup
    title: "Cantos Ativos"
    description: "Ações ao manter o cursor nos cantos da tela"
    icon: "focus-2"
    expanded: root.expandedGroups.corners
    onToggled: open => root.toggle("corners", open)
    UmbrielHotCornersCard { Layout.fillWidth: true }
  }
}
