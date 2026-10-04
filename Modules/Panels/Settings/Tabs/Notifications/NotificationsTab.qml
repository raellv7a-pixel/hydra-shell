pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

NSettingsGroupPage {
  id: root
  pageKey: "notifications"
  // Helper functions to update arrays immutably
  function addMonitor(list, name) {
    const arr = (list || []).slice();
    if (!arr.includes(name))
      arr.push(name);
    return arr;
  }
  function removeMonitor(list, name) {
    return (list || []).filter(function (n) {
      return n !== name;
    });
  }

  // File pickers for sound sub-tab
  function openUnifiedSoundPicker() {
    unifiedSoundFilePicker.open();
  }
  function openLowSoundPicker() {
    lowSoundFilePicker.open();
  }
  function openNormalSoundPicker() {
    normalSoundFilePicker.open();
  }
  function openCriticalSoundPicker() {
    criticalSoundFilePicker.open();
  }

  groups: [
    { key: "appearance", labelKey: "common.appearance", icon: "palette", content: appearanceContent },
    { key: "duration", labelKey: "common.duration", icon: "clock", content: durationContent },
    { key: "history", labelKey: "common.history", icon: "history", content: historyContent },
    { key: "sound", labelKey: "common.sound", icon: "volume", content: soundContent },
    { key: "toast", labelKey: "common.toast", icon: "bell", content: toastContent },
    { key: "rules", labelKey: "panels.notifications.rules-tab", icon: "list-check", content: rulesContent }
  ]

  Component {
    id: appearanceContent
    GeneralSubTab {
      addMonitor: root.addMonitor
      removeMonitor: root.removeMonitor
    }
  }
  Component { id: durationContent; DurationSubTab {} }
  Component { id: historyContent; HistorySubTab {} }
  Component {
    id: soundContent
    SoundSubTab {
      onOpenUnifiedPicker: root.openUnifiedSoundPicker()
      onOpenLowPicker: root.openLowSoundPicker()
      onOpenNormalPicker: root.openNormalSoundPicker()
      onOpenCriticalPicker: root.openCriticalSoundPicker()
    }
  }
  Component { id: toastContent; ToastSubTab {} }
  Component { id: rulesContent; RulesSubTab {} }

  // File Pickers for Sound Files
  NFilePicker {
    id: unifiedSoundFilePicker
    title: I18n.tr("panels.notifications.sounds-files-unified-select-title")
    selectionMode: "files"
    initialPath: Quickshell.env("HOME")
    nameFilters: ["*.wav", "*.mp3", "*.ogg", "*.flac", "*.m4a", "*.aac"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    const soundPath = paths[0];
                    Settings.data.notifications.sounds.normalSoundFile = soundPath;
                    Settings.data.notifications.sounds.lowSoundFile = soundPath;
                    Settings.data.notifications.sounds.criticalSoundFile = soundPath;
                  }
                }
  }

  NFilePicker {
    id: lowSoundFilePicker
    title: I18n.tr("panels.notifications.sounds-files-low-select-title")
    selectionMode: "files"
    initialPath: Quickshell.env("HOME")
    nameFilters: ["*.wav", "*.mp3", "*.ogg", "*.flac", "*.m4a", "*.aac"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.notifications.sounds.lowSoundFile = paths[0];
                  }
                }
  }

  NFilePicker {
    id: normalSoundFilePicker
    title: I18n.tr("panels.notifications.sounds-files-normal-select-title")
    selectionMode: "files"
    initialPath: Quickshell.env("HOME")
    nameFilters: ["*.wav", "*.mp3", "*.ogg", "*.flac", "*.m4a", "*.aac"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.notifications.sounds.normalSoundFile = paths[0];
                  }
                }
  }

  NFilePicker {
    id: criticalSoundFilePicker
    title: I18n.tr("panels.notifications.sounds-files-critical-select-title")
    selectionMode: "files"
    initialPath: Quickshell.env("HOME")
    nameFilters: ["*.wav", "*.mp3", "*.ogg", "*.flac", "*.m4a", "*.aac"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.notifications.sounds.criticalSoundFile = paths[0];
                  }
                }
  }
}
