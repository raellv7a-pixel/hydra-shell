import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "dock"
  groups: [
    { key: "appearance", labelKey: "common.appearance", icon: "palette", content: appearanceContent },
    { key: "monitors", labelKey: "common.monitors", icon: "device-desktop", content: monitorsContent }
  ]

  Component { id: appearanceContent; AppearanceSubTab {} }
  Component { id: monitorsContent; MonitorsSubTab {} }
}
