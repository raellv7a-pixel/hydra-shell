import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "about"
  groups: [
    { key: "info", labelKey: "common.info", icon: "info", content: infoContent },
    { key: "contributors", labelKey: "common.contributors", icon: "users", content: contributorsContent },
    { key: "supporters", labelKey: "common.supporters", icon: "heart", content: supportersContent }
  ]

  Component { id: infoContent; VersionSubTab {} }
  Component { id: contributorsContent; ContributorsSubTab {} }
  Component { id: supportersContent; SupportersSubTab {} }
}
