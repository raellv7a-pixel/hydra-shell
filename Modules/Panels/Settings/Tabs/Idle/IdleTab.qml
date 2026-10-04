import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "idle"
  groups: [
    { key: "behavior", labelKey: "panels.idle.tab-behavior", icon: "clock", content: behaviorContent },
    { key: "custom", labelKey: "panels.idle.tab-custom", icon: "settings-automation", content: customContent }
  ]

  Component { id: behaviorContent; BehaviorSubTab {} }
  Component { id: customContent; CustomSubTab {} }
}
