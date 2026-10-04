import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "plugins"
  groups: [
    { key: "installed", labelKey: "common.installed", icon: "plugin", content: installedContent },
    { key: "available", labelKey: "common.available", icon: "download", content: availableContent },
    { key: "sources", labelKey: "common.sources", icon: "world", content: sourcesContent }
  ]

  Component { id: installedContent; InstalledSubTab {} }
  Component { id: availableContent; AvailableSubTab {} }
  Component { id: sourcesContent; SourcesSubTab {} }
}
