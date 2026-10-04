import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "hooks"
  groups: [
    { key: "general", labelKey: "common.general", icon: "settings", content: generalContent },
    { key: "hooks", labelKey: "panels.hooks.title", icon: "list", content: hooksContent }
  ]

  Component { id: generalContent; GeneralSubTab {} }
  Component { id: hooksContent; HooksListSubTab {} }
}
