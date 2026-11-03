import QtQuick
import QtQuick.Layouts
import "Helpers/LauncherArtwork.js" as LauncherArtwork
import qs.Commons
import qs.Widgets

Flow {
  id: root
  required property var launcher
  property bool expanded: false
  readonly property var provider: launcher.currentProvider
  readonly property var categories: launcher.providerCategories
  readonly property var primary: launcher.catalogActive ? ["all", "Development", "AudioVideo", "Office", "System", "Network", "Game"] : ["all", "Development", "AudioVideo", "Office", "System", "Network"]
  readonly property var shown: provider !== launcher.defaultProvider || expanded ? categories : primary.filter(category => categories.includes(category))
  spacing: launcher.metrics.gapS
  function focusFirst() { if (pills.count) pills.itemAt(0).forceActiveFocus(); }
  function categoryIcon(category) { return LauncherArtwork.categoryIcon(category, provider, launcher.defaultProvider); }
  Repeater {
    id: pills
    model: root.shown
    LauncherHomeButton {
      id: pill
      required property string modelData
      launcher: root.launcher
      readonly property bool selected: root.provider === launcher.defaultProvider && launcher.effectiveState === "home" ? modelData === "all" : root.provider.selectedCategory === modelData
      text: modelData === "all" && root.provider === launcher.defaultProvider && launcher.effectiveState === "home" ? I18n.tr("launcher-home.all") : (root.provider.getCategoryName ? root.provider.getCategoryName(modelData) : modelData)
      surface: selected ? HydraColor.mPrimaryContainer : HydraColor.mSurfaceContainerHigh
      foreground: selected ? HydraColor.mOnPrimaryContainer : HydraColor.mOnSurface
      cornerRadius: height / 2
      implicitWidth: row.implicitWidth + padding * 2
      implicitHeight: launcher.metrics.pillHeight
      Accessible.selected: selected
      contentItem: RowLayout {
        id: row
        spacing: root.launcher.metrics.gapS
        NColorIcon { icon: root.categoryIcon(pill.modelData); size: Math.round(20 * Style.uiScaleRatio) }
        NText { text: pill.text; color: pill.foreground; pointSize: Style.fontSizeS; font.weight: pill.selected ? Style.fontWeightSemiBold : Style.fontWeightRegular }
      }
      onClicked: {
        if (launcher.currentProvider === launcher.defaultProvider) {
          if (modelData === "all" && launcher.effectiveState === "home") launcher.goHome();
          else launcher.openAllApps(modelData);
        } else launcher.selectCategoryWithSlide(root.categories.indexOf(modelData));
      }
    }
  }
  LauncherHomeButton {
    id: moreButton
    visible: root.provider === launcher.defaultProvider && root.categories.some(category => !root.primary.includes(category))
    launcher: root.launcher
    text: I18n.tr(root.expanded ? "launcher-home.less" : "launcher-home.more")
    cornerRadius: height / 2
    implicitHeight: launcher.metrics.pillHeight
    contentItem: RowLayout {
      spacing: root.launcher.metrics.gapS
      NText { text: moreButton.text; color: moreButton.foreground; pointSize: Style.fontSizeS }
      NIcon { icon: root.expanded ? "chevron-up" : "chevron-down"; color: moreButton.foreground; pointSize: Style.fontSizeS }
    }
    onClicked: root.expanded = !root.expanded
  }
}
