pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// One scroll is owned by SettingsContent; group content stays loaded while collapsed.
ColumnLayout {
  id: root

  required property string pageKey
  property var scrollView: null
  property var groups: []
  // Keep live summaries separate from descriptors so value changes do not
  // replace the Repeater model and recreate focused form controls.
  property var summaries: ({})
  property Component header: null
  default property alias content: extras.data

  readonly property var expandedGroups: {
    const saved = SettingsPanelService.settingsGroupStates[pageKey];
    return saved || (groups.length ? {
                                       [groups[0].key]: true
                                     } : ({}));
  }
  readonly property var navigationGroups: groups.filter(group => group.available !== false).map(group => ({
    key: group.key,
    title: group.title || I18n.tr(group.labelKey),
    icon: group.icon
  }))

  Layout.fillWidth: true
  spacing: Style.marginM

  function toggle(key, open) {
    SettingsPanelService.settingsGroupStates = Object.assign({}, SettingsPanelService.settingsGroupStates, {
                                                               [pageKey]: Object.assign({}, expandedGroups, {
                                                                                          [key]: open
                                                                                        })
                                                             });
  }

  function jump(key) {
    if (!groups.some(group => group.key === key && group.available !== false))
      return;
    toggle(key, true);
    jumpTimer.key = key;
    jumpTimer.restart();
  }

  function scrollTo(key) {
    if (!scrollView)
      return;
    const flick = scrollView.contentItem;
    const index = groups.findIndex(group => group.key === key);
    const card = groupRepeater.itemAt(index);
    if (!card)
      return;
    const y = card.mapToItem(flick.contentItem, 0, 0).y;
    flick.contentY = Math.max(0, Math.min(y, flick.contentHeight - flick.height));
  }

  function revealSettingsGroup(key) {
    if (groups.some(group => group.key === key && group.available !== false))
      toggle(key, true);
  }

  function navigateToSettingsGroup(index) {
    if (index >= 0 && index < groups.length)
      jump(groups[index].key);
  }

  Timer {
    id: jumpTimer
    property string key: ""
    interval: Style.animationFaster + 40
    onTriggered: root.scrollTo(key)
  }

  Loader {
    Layout.fillWidth: true
    active: root.header !== null
    visible: active
    sourceComponent: root.header
  }

  NSettingsGroupNav {
    groups: root.navigationGroups
    expandedGroups: root.expandedGroups
    onGroupSelected: key => root.jump(key)
  }

  Repeater {
    id: groupRepeater
    model: root.groups
    delegate: NSettingsGroupCard {
      id: card
      required property var modelData
      visible: modelData.available !== false
      title: modelData.title || I18n.tr(modelData.labelKey)
      description: modelData.description || ""
      icon: modelData.icon
      summary: root.summaries[modelData.key] || ""
      expanded: !!root.expandedGroups[modelData.key]
      onToggled: open => root.toggle(modelData.key, open)
      Loader {
        Layout.fillWidth: true
        active: card.modelData.available !== false
        sourceComponent: card.modelData.content
      }
    }
  }

  // Popup, model and Component declarations in the owning page do not take layout space.
  Item {
    id: extras
    Layout.fillWidth: true
    implicitHeight: 0
  }
}
