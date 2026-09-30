import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Hydra
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: 0

  Component.onCompleted: {
    // Fill out availableWidgets ListModel
    availableWidgets.clear();
    var sortedEntries = ControlCenterWidgetRegistry.getAvailableWidgets().slice().sort();
    sortedEntries.forEach(entry => {
                            const isPlugin = ControlCenterWidgetRegistry.isPluginWidget(entry);
                            let displayName = entry;
                            let badges = [];
                            if (isPlugin) {
                              const pluginId = entry.replace("plugin:", "");
                              const manifest = PluginRegistry.getPluginManifest(pluginId);
                              if (manifest && manifest.name) {
                                displayName = manifest.name;
                              } else {
                                displayName = pluginId;
                              }
                              badges.push({
                                            "icon": "plugin",
                                            "color": Color.mSecondary
                                          });
                            }
                            availableWidgets.append({
                                                      "key": entry,
                                                      "name": displayName,
                                                      "badges": badges
                                                    });
                          });
  }

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NTabButton {
      text: I18n.tr("common.appearance")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    NTabButton {
      text: I18n.tr("common.cards")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
    NTabButton {
      text: I18n.tr("common.shortcuts")
      tabIndex: 2
      checked: subTabBar.currentIndex === 2
    }
    NTabButton {
      text: I18n.tr("common.profile")
      tabIndex: 3
      checked: subTabBar.currentIndex === 3
    }
    NTabButton {
      text: I18n.tr("common.effects")
      tabIndex: 4
      checked: subTabBar.currentIndex === 4
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex
    Layout.fillWidth: true
    Layout.fillHeight: true

    AppearanceSubTab {}

    CardsSubTab {}

    ShortcutsSubTab {
      availableWidgets: availableWidgets
      onAddWidgetToSection: (widgetId, section) => _addWidgetToSection(widgetId, section)
      onRemoveWidgetFromSection: (section, index) => _removeWidgetFromSection(section, index)
      onReorderWidgetInSection: (section, fromIndex, toIndex) => _reorderWidgetInSection(section, fromIndex, toIndex)
      onUpdateWidgetSettingsInSection: (section, index, settings) => _updateWidgetSettingsInSection(section, index, settings)
      onMoveWidgetBetweenSections: (fromSection, index, toSection) => _moveWidgetBetweenSections(fromSection, index, toSection)
      onOpenPluginSettingsRequested: manifest => pluginSettingsDialog.openPluginSettings(manifest)
    }

    ProfileSubTab {}

    EffectsSubTab {}
  }

  // ---------------------------------
  // Signal functions
  // ---------------------------------
  function _copyShortcutSection(section) {
    var source = Settings.data.controlCenter.shortcuts[section];
    var copy = [];
    for (var i = 0; i < source.length; i++)
      copy.push(source[i]);
    return copy;
  }

  function _replaceShortcutSection(section, entries) {
    var target = Settings.data.controlCenter.shortcuts[section];
    target.length = 0;
    for (var i = 0; i < entries.length; i++)
      target.push(entries[i]);
    Settings.saveImmediate();
  }

  function _addWidgetToSection(widgetId, section) {
    var newWidget = {
      "id": widgetId
    };
    if (ControlCenterWidgetRegistry.widgetHasUserSettings(widgetId)) {
      var metadata = ControlCenterWidgetRegistry.widgetMetadata[widgetId];
      if (metadata) {
        Object.keys(metadata).forEach(function (key) {
          newWidget[key] = metadata[key];
        });
      }
    }
    var newArray = _copyShortcutSection(section);
    newArray.push(newWidget);
    _replaceShortcutSection(section, newArray);
  }

  function _removeWidgetFromSection(section, index) {
    var newArray = _copyShortcutSection(section);
    if (index >= 0 && index < newArray.length) {
      newArray.splice(index, 1);
      _replaceShortcutSection(section, newArray);
    }
  }

  function _reorderWidgetInSection(section, fromIndex, toIndex) {
    var newArray = _copyShortcutSection(section);
    if (fromIndex >= 0 && fromIndex < newArray.length && toIndex >= 0 && toIndex < newArray.length) {
      var item = newArray[fromIndex];
      newArray.splice(fromIndex, 1);
      newArray.splice(toIndex, 0, item);
      _replaceShortcutSection(section, newArray);
    }
  }

  function _moveWidgetBetweenSections(fromSection, index, toSection) {
    var sourceArray = _copyShortcutSection(fromSection);
    var targetArray = _copyShortcutSection(toSection);
    if (index >= 0 && index < sourceArray.length) {
      var widget = sourceArray.splice(index, 1)[0];
      targetArray.push(widget);
      _replaceShortcutSection(fromSection, sourceArray);
      _replaceShortcutSection(toSection, targetArray);
    }
  }

  function _updateWidgetSettingsInSection(section, index, settings) {
    var newArray = _copyShortcutSection(section);
    if (index < 0 || index >= newArray.length)
      return;
    newArray[index] = settings;
    _replaceShortcutSection(section, newArray);
  }

  // Base list model for all combo boxes
  ListModel {
    id: availableWidgets
  }

  // Shared Plugin Settings Popup
  NPluginSettingsPopup {
    id: pluginSettingsDialog
    parent: Overlay.overlay
    showToastOnSave: false
  }
}
