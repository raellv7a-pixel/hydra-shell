import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "launcher"
  groups: [
    { key: "general", labelKey: "common.general", icon: "settings", content: generalContent },
    { key: "hero", labelKey: "launcher-home.settings.hero-title", icon: "photo", content: heroContent },
    { key: "folders", labelKey: "launcher-home.folders-title", icon: "folder", content: foldersContent },
    { key: "clipboard", labelKey: "common.clipboard", icon: "clipboard", content: clipboardContent },
    { key: "execute", labelKey: "common.execute", icon: "terminal", content: executeContent }
  ]

  Component { id: generalContent; GeneralSubTab {} }
  Component { id: heroContent; HeroSubTab {} }
  Component { id: foldersContent; FoldersSubTab {} }
  Component { id: clipboardContent; ClipboardSubTab {} }
  Component { id: executeContent; ExecuteSubTab {} }
}
