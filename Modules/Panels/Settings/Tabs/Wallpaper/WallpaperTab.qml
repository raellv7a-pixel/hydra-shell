pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NSettingsGroupPage {
  id: root
  pageKey: "wallpaper"

  property var screen

  function openMainFolderPicker() {
    mainFolderPicker.open();
  }

  function openMonitorFolderPicker(monitorName) {
    specificFolderMonitorName = monitorName;
    monitorFolderPicker.open();
  }

  property string specificFolderMonitorName: ""

  groups: [
    { key: "general", labelKey: "common.general", icon: "image", content: generalContent },
    { key: "look", labelKey: "common.look", icon: "palette", content: lookContent },
    { key: "automation", labelKey: "common.automation", icon: "settings-automation", content: automationContent }
  ]

  Component {
    id: generalContent
    GeneralSubTab {
      screen: root.screen
      onOpenMainFolderPicker: root.openMainFolderPicker()
      onOpenMonitorFolderPicker: monitorName => root.openMonitorFolderPicker(monitorName)
    }
  }
  Component { id: lookContent; LookAndFeelSubTab { screen: root.screen } }
  Component { id: automationContent; AutomationSubTab {} }

  NFilePicker {
    id: mainFolderPicker
    selectionMode: "folders"
    title: I18n.tr("setup.wallpaper.dir-select-title")
    initialPath: Settings.data.wallpaper.directory || Quickshell.env("HOME") + "/Pictures"
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.wallpaper.directory = paths[0];
                  }
                }
  }

  NFilePicker {
    id: monitorFolderPicker
    selectionMode: "folders"
    title: I18n.tr("panels.wallpaper.settings-select-monitor-folder")
    initialPath: WallpaperService.getMonitorDirectory(specificFolderMonitorName) || Quickshell.env("HOME") + "/Pictures"
    onAccepted: paths => {
                  if (paths.length > 0) {
                    WallpaperService.setMonitorDirectory(specificFolderMonitorName, paths[0]);
                  }
                }
  }
}
