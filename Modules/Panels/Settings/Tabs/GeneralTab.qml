import QtQuick
import "General"
import qs.Widgets

NSettingsGroupPage {
  id: root
  pageKey: "general"
  groups: [
    { key: "basics", labelKey: "panels.general.tab-basics", icon: "settings", content: basicsContent },
    { key: "keybinds", labelKey: "panels.general.tab-keybinds", icon: "keyboard", content: keybindsContent }
  ]

  Component { id: basicsContent; BasicsSubTab {} }
  Component { id: keybindsContent; KeybindsSubTab {} }
}
