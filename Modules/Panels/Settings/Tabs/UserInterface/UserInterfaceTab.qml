import QtQuick
import qs.Commons
import qs.Widgets

NSettingsGroupPage {
  pageKey: "interface"
  summaries: ({
                appearance: I18n.tr("settings.content.appearance-summary", {
                                      scale: Math.round(Settings.data.general.scaleRatio * 100),
                                      motion: Style.animationNormal > 0 ? I18n.tr("common.enabled") : I18n.tr("common.disabled")
                                    })
              })
  groups: [
    {
      key: "appearance",
      labelKey: "common.appearance",
      icon: "palette",
      content: appearanceContent
    },
    {
      key: "panels",
      labelKey: "common.panels",
      icon: "layout-dashboard",
      content: panelsContent
    },
    {
      key: "corners",
      labelKey: "common.screen-corners",
      icon: "focus-2",
      content: cornersContent
    }
  ]

  Component {
    id: appearanceContent
    AppearanceSubTab {}
  }
  Component {
    id: panelsContent
    PanelsSubTab {}
  }
  Component {
    id: cornersContent
    ScreenCornersSubTab {}
  }
}
