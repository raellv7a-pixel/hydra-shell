import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NSettingsAppearancePreview {
    Layout.fillWidth: true
  }

  NSettingsSection {
    title: I18n.tr("settings.content.reading")
    icon: "text-size"
    NToggle {
      label: I18n.tr("panels.user-interface.tooltips-label")
      description: I18n.tr("panels.user-interface.tooltips-description")
      checked: Settings.data.ui.tooltipsEnabled
      defaultValue: Settings.getDefaultValue("ui.tooltipsEnabled")
      onToggled: checked => Settings.data.ui.tooltipsEnabled = checked
    }

    NToggle {
      label: I18n.tr("panels.user-interface.scrollbar-always-visible-label")
      description: I18n.tr("panels.user-interface.scrollbar-always-visible-description")
      checked: Settings.data.ui.scrollbarAlwaysVisible
      defaultValue: Settings.getDefaultValue("ui.scrollbarAlwaysVisible")
      onToggled: checked => Settings.data.ui.scrollbarAlwaysVisible = checked
    }
  }

  NSettingsSection {
    title: I18n.tr("settings.content.surfaces")
    icon: "layers-intersect"

    NComboBox {
      id: visualVariant
      Layout.fillWidth: true
      minimumWidth: 180 * Style.uiScaleRatio
      label: I18n.tr("panels.user-interface.visual-variant-label")
      description: I18n.tr("panels.user-interface.visual-profile-description-" + Style.visualVariant)
      model: Style.visualProfileIds.map(id => ({
        "key": id,
        "name": I18n.tr("panels.user-interface.visual-variant-" + id)
      }))
      currentKey: Settings.data.ui.visualVariant
      defaultValue: Settings.getDefaultValue("ui.visualVariant")
      onSelected: key => Settings.data.ui.visualVariant = key
      Component.onCompleted: {
        comboBox.Accessible.name = Qt.binding(() => visualVariant.label);
        comboBox.Accessible.description = Qt.binding(() => visualVariant.description);
      }
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Style.customMaterial
      label: I18n.tr("panels.user-interface.glass-tint-label")
      description: I18n.tr(Style.profileUsesGlass ? "panels.user-interface.glass-tint-description" : "panels.user-interface.material-tint-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.glassTint
      defaultValue: Settings.getDefaultValue("ui.glassTint")
      onMoved: value => Settings.data.ui.glassTint = value
      text: Math.round(value * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Style.profileUsesGlass
      enabled: Style.glassEffectsEnabled
      label: I18n.tr("panels.user-interface.glass-blur-label")
      description: I18n.tr("panels.user-interface.glass-blur-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.glassBlur
      defaultValue: Settings.getDefaultValue("ui.glassBlur")
      onMoved: value => Settings.data.ui.glassBlur = value
      text: Math.round(value * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Style.customMaterial
      label: I18n.tr("panels.user-interface.glass-edge-light-label")
      description: I18n.tr(Style.profileUsesGlass ? "panels.user-interface.glass-edge-light-description" : "panels.user-interface.material-edge-light-description")
      from: 0
      to: 0.3
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.glassEdgeLight
      defaultValue: Settings.getDefaultValue("ui.glassEdgeLight")
      onMoved: value => Settings.data.ui.glassEdgeLight = value
      text: Math.round(value * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Style.customMaterial && (Style.materialProfile.light > 0 || Style.materialProfile.chrome > 0 || Style.materialProfile.bloom > 0)
      enabled: Style.materialEffectsEnabled
      label: I18n.tr("panels.user-interface.material-lighting-label")
      description: I18n.tr("panels.user-interface.material-lighting-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.materialLighting
      defaultValue: Settings.getDefaultValue("ui.materialLighting")
      onMoved: value => Settings.data.ui.materialLighting = value
      text: Math.round(value * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Style.customMaterial && Style.materialProfile.texture > 0
      enabled: Style.materialEffectsEnabled
      label: I18n.tr("panels.user-interface.material-texture-label")
      description: I18n.tr("panels.user-interface.material-texture-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.materialTexture
      defaultValue: Settings.getDefaultValue("ui.materialTexture")
      onMoved: value => Settings.data.ui.materialTexture = value
      text: Math.round(value * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      visible: Style.profileUsesGlass && Style.materialProfile.refraction > 0
      enabled: Style.glassEffectsEnabled
      label: I18n.tr("panels.user-interface.material-refraction-label")
      description: I18n.tr("panels.user-interface.material-refraction-description")
      from: 0
      to: 1
      stepSize: 0.01
      showReset: true
      value: Settings.data.ui.materialRefraction
      defaultValue: Settings.getDefaultValue("ui.materialRefraction")
      onMoved: value => Settings.data.ui.materialRefraction = value
      text: Math.round(value * 100) + "%"
    }

    NText {
      Layout.fillWidth: true
      visible: Style.profileUsesGlass
      text: I18n.tr("panels.user-interface.glass-fallback-description")
      pointSize: Style.fontSizeS
      color: HydraColor.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }

    NToggle {
      label: I18n.tr("panels.user-interface.box-border-label")
      description: I18n.tr("panels.user-interface.box-border-description")
      checked: Settings.data.ui.boxBorderEnabled
      defaultValue: Settings.getDefaultValue("ui.boxBorderEnabled")
      onToggled: checked => Settings.data.ui.boxBorderEnabled = checked
    }
    NToggle {
      label: I18n.tr("panels.user-interface.shadows-label")
      description: I18n.tr("panels.user-interface.shadows-description")
      checked: Settings.data.general.enableShadows
      defaultValue: Settings.getDefaultValue("general.enableShadows")
      onToggled: checked => Settings.data.general.enableShadows = checked
    }

    NComboBox {
      visible: Settings.data.general.enableShadows
      label: I18n.tr("panels.user-interface.shadows-direction-label")
      description: I18n.tr("panels.user-interface.shadows-direction-description")
      Layout.fillWidth: true

      readonly property var shadowOptionsMap: ({
                                                 "top_left": {
                                                   "name": I18n.tr("positions.top-left"),
                                                   "p": Qt.point(-2, -2)
                                                 },
                                                 "top": {
                                                   "name": I18n.tr("positions.top"),
                                                   "p": Qt.point(0, -3)
                                                 },
                                                 "top_right": {
                                                   "name": I18n.tr("positions.top-right"),
                                                   "p": Qt.point(2, -2)
                                                 },
                                                 "left": {
                                                   "name": I18n.tr("positions.left"),
                                                   "p": Qt.point(-3, 0)
                                                 },
                                                 "center": {
                                                   "name": I18n.tr("positions.center"),
                                                   "p": Qt.point(0, 0)
                                                 },
                                                 "right": {
                                                   "name": I18n.tr("positions.right"),
                                                   "p": Qt.point(3, 0)
                                                 },
                                                 "bottom_left": {
                                                   "name": I18n.tr("positions.bottom-left"),
                                                   "p": Qt.point(-2, 2)
                                                 },
                                                 "bottom": {
                                                   "name": I18n.tr("positions.bottom"),
                                                   "p": Qt.point(0, 3)
                                                 },
                                                 "bottom_right": {
                                                   "name": I18n.tr("positions.bottom-right"),
                                                   "p": Qt.point(2, 3)
                                                 }
                                               })

      model: Object.keys(shadowOptionsMap).map(function (k) {
        return {
          "key": k,
          "name": shadowOptionsMap[k].name
        };
      })

      currentKey: Settings.data.general.shadowDirection
      defaultValue: Settings.getDefaultValue("general.shadowDirection")

      onSelected: function (key) {
        var opt = shadowOptionsMap[key];
        if (opt) {
          Settings.data.general.shadowDirection = key;
          Settings.data.general.shadowOffsetX = opt.p.x;
          Settings.data.general.shadowOffsetY = opt.p.y;
        }
      }
    }
    NToggle {
      label: I18n.tr("panels.user-interface.blur-behind-label")
      description: I18n.tr("panels.user-interface.blur-behind-description")
      checked: Settings.data.general.enableBlurBehind
      defaultValue: Settings.getDefaultValue("general.enableBlurBehind")
      onToggled: checked => Settings.data.general.enableBlurBehind = checked
    }

    NToggle {
      label: I18n.tr("panels.user-interface.translucent-widgets-label")
      description: I18n.tr("panels.user-interface.translucent-widgets-description")
      checked: Settings.data.ui.translucentWidgets
      defaultValue: Settings.getDefaultValue("ui.translucentWidgets")
      onToggled: checked => Settings.data.ui.translucentWidgets = checked
    }
  }
  NSettingsSection {
    title: I18n.tr("settings.content.geometry")
    icon: "dimensions"

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.scaling-label")
      description: I18n.tr("panels.user-interface.scaling-description")
      from: 0.8
      to: 1.2
      stepSize: 0.05
      showReset: true
      value: Settings.data.general.scaleRatio
      defaultValue: Settings.getDefaultValue("general.scaleRatio")
      onMoved: value => Settings.data.general.scaleRatio = value
      text: Math.floor(Settings.data.general.scaleRatio * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.box-border-radius-label")
      description: I18n.tr("panels.user-interface.box-border-radius-description")
      from: 0
      to: 2
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.radiusRatio
      defaultValue: Settings.getDefaultValue("general.radiusRatio")
      onMoved: value => Settings.data.general.radiusRatio = value
      text: Math.floor(Settings.data.general.radiusRatio * 100) + "%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.user-interface.control-border-radius-label")
      description: I18n.tr("panels.user-interface.control-border-radius-description")
      from: 0
      to: 2
      stepSize: 0.01
      showReset: true
      value: Settings.data.general.iRadiusRatio
      defaultValue: Settings.getDefaultValue("general.iRadiusRatio")
      onMoved: value => Settings.data.general.iRadiusRatio = value
      text: Math.floor(Settings.data.general.iRadiusRatio * 100) + "%"
    }
  }

  NSettingsSection {
    title: I18n.tr("settings.content.motion")
    icon: "player-play"

    NToggle {
      label: I18n.tr("panels.user-interface.animation-disable-label")
      description: I18n.tr("panels.user-interface.animation-disable-description")
      checked: Settings.data.general.animationDisabled
      defaultValue: Settings.getDefaultValue("general.animationDisabled")
      onToggled: checked => Settings.data.general.animationDisabled = checked
    }

    ColumnLayout {
      spacing: Style.marginXXS
      Layout.fillWidth: true
      visible: !Settings.data.general.animationDisabled

      NValueSlider {
        Layout.fillWidth: true
        label: I18n.tr("panels.user-interface.animation-speed-label")
        description: I18n.tr("panels.user-interface.animation-speed-description")
        from: 0
        to: 2.0
        stepSize: 0.01
        showReset: true
        value: Settings.data.general.animationSpeed
        defaultValue: Settings.getDefaultValue("general.animationSpeed")
        onMoved: value => Settings.data.general.animationSpeed = Math.max(value, 0.05)
        text: Math.round(Settings.data.general.animationSpeed * 100) + "%"
      }
    }
  }
}
