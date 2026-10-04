import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

ColumnLayout {
  id: root
  readonly property var settings: UmbrielSettingsStore
  readonly property var overview: settings.draft.overview || ({})
  Layout.fillWidth: true
  spacing: Style.marginXL
  enabled: settings.loaded && !settings.externallyOwned && !settings.busy

  NText {
    text: I18n.tr("panels.umbriel.overview-group-scale")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightSemiBold
    color: Color.mPrimary
  }
  NValueSlider {
    label: I18n.tr("panels.umbriel.overview-zoom")
    description: I18n.tr("panels.umbriel.overview-zoom-description")
    from: 0.1; to: 0.75; stepSize: 0.01
    value: root.overview.zoom ?? 0.5
    text: Number(value).toFixed(2)
    onMoved: value => root.settings.updateOverview("zoom", Number(value.toFixed(2)))
  }
  NValueSlider {
    label: I18n.tr("panels.umbriel.overview-horizontal")
    description: I18n.tr("panels.umbriel.overview-horizontal-description")
    from: 0.1; to: 10; stepSize: 0.1
    value: root.overview.scroll_factor_horizontal ?? 1
    text: Number(value).toFixed(1)
    onMoved: value => root.settings.updateOverview("scroll_factor_horizontal", Number(value.toFixed(1)))
  }
  NValueSlider {
    label: I18n.tr("panels.umbriel.overview-vertical")
    description: I18n.tr("panels.umbriel.overview-vertical-description")
    from: 0.1; to: 10; stepSize: 0.1
    value: root.overview.scroll_factor_vertical ?? 1
    text: Number(value).toFixed(1)
    onMoved: value => root.settings.updateOverview("scroll_factor_vertical", Number(value.toFixed(1)))
  }
  NText {
    Layout.topMargin: Style.marginM
    text: I18n.tr("panels.umbriel.overview-group-appearance")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightSemiBold
    color: Color.mPrimary
  }
  NToggle {
    label: I18n.tr("panels.umbriel.overview-blur")
    description: I18n.tr("panels.umbriel.overview-blur-description")
    checked: root.overview.background_blur ?? true
    onToggled: checked => root.settings.updateOverview("background_blur", checked)
  }
  NToggle {
    label: I18n.tr("panels.umbriel.overview-wallpaper")
    description: I18n.tr("panels.umbriel.overview-wallpaper-description")
    checked: root.overview.workspace_wallpaper ?? true
    onToggled: checked => root.settings.updateOverview("workspace_wallpaper", checked)
  }
  NText {
    Layout.topMargin: Style.marginM
    text: I18n.tr("panels.umbriel.overview-group-navigation")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightSemiBold
    color: Color.mPrimary
  }
  NToggle {
    label: I18n.tr("panels.umbriel.overview-shortcuts")
    description: I18n.tr("panels.umbriel.overview-shortcuts-description")
    checked: root.overview.shortcuts ?? true
    onToggled: checked => root.settings.updateOverview("shortcuts", checked)
  }
  NTextInput {
    Layout.fillWidth: true
    label: I18n.tr("panels.umbriel.overview-keys")
    description: I18n.tr("panels.umbriel.overview-keys-description")
    text: root.overview.shortcut_keys ?? "1234567890"
    onEditingFinished: root.settings.updateOverview("shortcut_keys", text)
  }
}
