pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "General"
import qs.Widgets

NSettingsGroupPage {
  id: root
  property ShellScreen screen: null
  signal wallpaperRequested
  signal colorsRequested
  pageKey: "general"
  header: Component {
    GeneralOverview {
      screen: root.screen
      onWallpaperRequested: root.wallpaperRequested()
      onColorsRequested: root.colorsRequested()
    }
  }
  groups: [
    {
      key: "basics",
      labelKey: "panels.general.tab-basics",
      icon: "settings",
      content: basicsContent
    },
    {
      key: "keybinds",
      labelKey: "panels.general.tab-keybinds",
      icon: "keyboard",
      content: keybindsContent
    }
  ]

  Component {
    id: basicsContent
    BasicsSubTab {}
  }
  Component {
    id: keybindsContent
    KeybindsSubTab {}
  }
}
