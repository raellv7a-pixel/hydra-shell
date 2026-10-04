import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "interface"
  groups: [
    { key: "appearance", labelKey: "common.appearance", icon: "palette", content: appearanceContent },
    { key: "panels", labelKey: "common.panels", icon: "layout-dashboard", content: panelsContent },
    { key: "corners", labelKey: "common.screen-corners", icon: "focus-2", content: cornersContent }
  ]

  Component { id: appearanceContent; AppearanceSubTab {} }
  Component { id: panelsContent; PanelsSubTab {} }
  Component { id: cornersContent; ScreenCornersSubTab {} }
}
