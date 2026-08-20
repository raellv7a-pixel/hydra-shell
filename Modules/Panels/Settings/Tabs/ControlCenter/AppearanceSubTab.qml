import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.fillHeight: true

  function dtr(key) {
    return I18n.tr("panels.dashboard." + key);
  }

  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NComboBox {
      id: controlCenterPosition
      label: I18n.tr("common.position")
      description: I18n.tr("panels.control-center.position-description")
      Layout.fillWidth: true
      model: [
        {
          "key": "close_to_bar_button",
          "name": I18n.tr("positions.close-to-bar")
        },
        {
          "key": "center",
          "name": I18n.tr("positions.center")
        },
        {
          "key": "top_center",
          "name": I18n.tr("positions.top-center")
        },
        {
          "key": "top_left",
          "name": I18n.tr("positions.top-left")
        },
        {
          "key": "top_right",
          "name": I18n.tr("positions.top-right")
        },
        {
          "key": "center_left",
          "name": I18n.tr("positions.center-left")
        },
        {
          "key": "center_right",
          "name": I18n.tr("positions.center-right")
        },
        {
          "key": "bottom_center",
          "name": I18n.tr("positions.bottom-center")
        },
        {
          "key": "bottom_left",
          "name": I18n.tr("positions.bottom-left")
        },
        {
          "key": "bottom_right",
          "name": I18n.tr("positions.bottom-right")
        }
      ]
      currentKey: Settings.data.controlCenter.position
      onSelected: function (key) {
        Settings.data.controlCenter.position = key;
      }
      defaultValue: Settings.getDefaultValue("controlCenter.position")
    }

    NToggle {
      Layout.fillWidth: true
      label: root.dtr("settingsPanelDetached")
      description: root.dtr("settingsPanelDetachedDesc")
      checked: Settings.data.controlCenter.detached
      onToggled: checked => Settings.data.controlCenter.detached = checked
      defaultValue: Settings.getDefaultValue("controlCenter.detached")
    }

    NComboBox {
      id: diskPathComboBox
      Layout.fillWidth: true
      label: I18n.tr("panels.control-center.system-monitor-disk-path-label")
      description: I18n.tr("panels.control-center.system-monitor-disk-path-description")
      model: {
        const paths = Object.keys(SystemStatService.diskPercents).sort();
        return paths.map(path => ({
                                    key: path,
                                    name: path
                                  }));
      }
      currentKey: Settings.data.controlCenter.diskPath || "/"
      onSelected: key => Settings.data.controlCenter.diskPath = key
      defaultValue: Settings.getDefaultValue("controlCenter.diskPath") || "/"
    }

    NHeader {
      label: root.dtr("settingsDimensions")
    }

    NValueSlider {
      Layout.fillWidth: true
      label: root.dtr("settingsPanelWidth")
      from: 800
      to: 1400
      stepSize: 20
      showReset: true
      value: Settings.data.controlCenter.panelWidth
      onMoved: val => Settings.data.controlCenter.panelWidth = Math.round(val)
      defaultValue: Settings.getDefaultValue("controlCenter.panelWidth")
      text: Settings.data.controlCenter.panelWidth + "px"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: root.dtr("settingsPanelHeight")
      from: 500
      to: 950
      stepSize: 20
      showReset: true
      value: Settings.data.controlCenter.panelHeight
      onMoved: val => Settings.data.controlCenter.panelHeight = Math.round(val)
      defaultValue: Settings.getDefaultValue("controlCenter.panelHeight")
      text: Settings.data.controlCenter.panelHeight + "px"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: root.dtr("settingsPanelScale")
      from: 0.7
      to: 1.3
      stepSize: 0.05
      showReset: true
      value: Settings.data.controlCenter.panelScale
      onMoved: val => Settings.data.controlCenter.panelScale = Math.round(val * 100) / 100
      defaultValue: Settings.getDefaultValue("controlCenter.panelScale")
      text: Math.round(Settings.data.controlCenter.panelScale * 100) + "%"
    }
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
