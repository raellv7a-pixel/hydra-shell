import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Flow {
  id: root
  required property var launcher
  property bool expanded: false
  readonly property var provider: launcher.currentProvider
  readonly property var categories: launcher.providerCategories
  readonly property var primary: ["all", "applications", "Development", "AudioVideo", "Office", "System", "Network"]
  readonly property var shown: provider !== launcher.defaultProvider ? categories : (expanded ? ["applications"].concat(categories) : primary.filter(category => category === "applications" || categories.includes(category)))
  spacing: launcher.metrics.gapS
  function focusFirst() { if (pills.count) pills.itemAt(0).forceActiveFocus(); }
  Repeater {
    id: pills
    model: root.shown
    LauncherHomeButton {
      id: pill
      required property string modelData
      launcher: root.launcher
      readonly property bool selected: modelData === "all" && launcher.effectiveState === "home" || (modelData === "applications" && launcher.effectiveState === "all_apps" && root.provider.selectedCategory === "all") || (modelData !== "all" && launcher.effectiveState !== "home" && root.provider.selectedCategory === modelData)
      text: modelData === "all" ? I18n.tr("launcher-home.all") : (modelData === "applications" ? I18n.tr("launcher-home.applications") : (root.provider.getCategoryName ? root.provider.getCategoryName(modelData) : modelData))
      surface: selected ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh
      foreground: selected ? Color.mOnPrimaryContainer : Color.mOnSurface
      cornerRadius: height / 2
      implicitWidth: row.implicitWidth + padding * 2
      implicitHeight: launcher.metrics.pillHeight
      Accessible.selected: selected
      contentItem: RowLayout {
        id: row
        spacing: root.launcher.metrics.gapS
        NIcon { icon: root.provider.categoryIcons ? root.provider.categoryIcons[pill.modelData] || "apps" : "apps"; color: pill.foreground; pointSize: Style.fontSizeL }
        NText { text: pill.text; color: pill.foreground; pointSize: Style.fontSizeS }
      }
      onClicked: {
        if (launcher.currentProvider === launcher.defaultProvider) {
          if (modelData === "all") launcher.goHome();
          else launcher.openAllApps(modelData === "applications" ? "all" : modelData);
        } else launcher.selectCategoryWithSlide(root.categories.indexOf(modelData));
      }
    }
  }
  LauncherHomeButton {
    visible: root.provider === launcher.defaultProvider && root.categories.some(category => !root.primary.includes(category))
    launcher: root.launcher
    text: I18n.tr(root.expanded ? "launcher-home.less" : "launcher-home.more")
    cornerRadius: height / 2
    implicitHeight: launcher.metrics.pillHeight
    onClicked: root.expanded = !root.expanded
  }
}
