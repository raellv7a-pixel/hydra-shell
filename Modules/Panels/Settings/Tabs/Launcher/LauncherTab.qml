import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "launcher"
  groups: [
    { key: "general", labelKey: "common.general", icon: "settings", content: generalContent },
    { key: "clipboard", labelKey: "common.clipboard", icon: "clipboard", content: clipboardContent },
    { key: "execute", labelKey: "common.execute", icon: "terminal", content: executeContent }
  ]

  Component { id: generalContent; GeneralSubTab {} }
  Component { id: clipboardContent; ClipboardSubTab {} }
  Component { id: executeContent; ExecuteSubTab {} }
}
