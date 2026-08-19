import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.Media
import qs.Services.Networking
import qs.Services.Power
import qs.Services.System
import qs.Services.UI
DashboardCard {
  id: quickActionsCard
  styleKey: "quickActions"
  styleRoot: true

  property int toolsTabIndex: 0
  readonly property var screenToolkitMain: ScreenToolkitService.mainInstance

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginS

    HeaderRow {
      panelRoot: quickActionsCard.panelRoot
      title: panelRoot.tr("controls")
      subtitle: panelRoot.tr("quick")
    }

    NTabBar {
      id: quickActionsTabs
      Layout.fillWidth: true
      tabHeight: Math.round(28 * panelRoot.panelUnit)
      distributeEvenly: true
      currentIndex: quickActionsCard.toolsTabIndex
      onCurrentIndexChanged: quickActionsCard.toolsTabIndex = currentIndex

      NTabButton {
        text: panelRoot.tr("controls")
        icon: "adjustments-horizontal"
        pointSize: Style.fontSizeXS
        tabIndex: 0
        checked: quickActionsTabs.currentIndex === 0
      }

      NTabButton {
        text: panelRoot.tr("screenToolsTab")
        icon: "wand"
        pointSize: Style.fontSizeXS
        tabIndex: 1
        checked: quickActionsTabs.currentIndex === 1
      }
    }

    GridLayout {
      Layout.fillWidth: true
      visible: quickActionsCard.toolsTabIndex === 0
      columns: 2
      columnSpacing: Style.marginS
      rowSpacing: Style.marginS

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("network")
        detailText: NetworkService.wifiConnected ? (NetworkService.activeWifiDetails.connectionName || NetworkService.activeWifiIf || panelRoot.tr("openPanel")) : panelRoot.tr("openPanel")
        secondaryIcon: "settings"
        secondaryTooltip: panelRoot.tr("networkDetails")
        iconName: NetworkService.wifiEnabled ? "wifi" : "wifi-off"
        active: NetworkService.wifiEnabled
        onTriggered: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
        onSecondaryTriggered: panelRoot.toggleNativePanel("networkPanel")
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("bluetooth")
        detailText: panelRoot.bluetoothDetailText()
        secondaryIcon: "settings"
        secondaryTooltip: panelRoot.tr("bluetoothDetails")
        hoverTooltip: panelRoot.bluetoothTooltipRows()
        iconName: !BluetoothService.enabled ? "bluetooth-off" : ((BluetoothService.connectedDevices && BluetoothService.connectedDevices.length > 0) ? "bluetooth-connected" : "bluetooth")
        active: BluetoothService.enabled
        onTriggered: BluetoothService.setBluetoothEnabled(!BluetoothService.enabled)
        onSecondaryTriggered: panelRoot.toggleNativePanel("bluetoothPanel")
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("dnd")
        detailText: panelRoot.tr("clearNotifications")
        secondaryIcon: "trash"
        secondaryTooltip: panelRoot.tr("clearNotifications")
        iconName: NotificationService.doNotDisturb ? "bell-off" : "bell"
        active: NotificationService.doNotDisturb
        onTriggered: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
        onSecondaryTriggered: NotificationService.clearHistory()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("microphone")
        detailText: Math.round(AudioService.inputVolume * 100) + "%"
        secondaryIcon: "adjustments-horizontal"
        secondaryTooltip: panelRoot.tr("audioDetails")
        iconName: AudioService.inputMuted ? "microphone-off" : "microphone"
        active: !AudioService.inputMuted
        onTriggered: AudioService.setInputMuted(!AudioService.inputMuted)
        onSecondaryTriggered: panelRoot.toggleNativePanel("audioPanel")
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("game")
        detailText: PowerProfileService.available ? PowerProfileService.getName() : panelRoot.tr("disabled")
        secondaryIcon: PowerProfileService.available ? PowerProfileService.getIcon() : "battery-off"
        secondaryTooltip: panelRoot.tr("cyclePowerProfile")
        iconName: "device-gamepad-2"
        active: PowerProfileService.noctaliaPerformanceMode
        onTriggered: PowerProfileService.toggleNoctaliaPerformance()
        onSecondaryTriggered: PowerProfileService.cycleProfile()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("awake")
        detailText: IdleInhibitorService.isInhibited ? panelRoot.tr("enabled") : panelRoot.tr("disabled")
        secondaryIcon: "power"
        secondaryTooltip: panelRoot.tr("sessionMenu")
        iconName: "moon"
        active: IdleInhibitorService.isInhibited
        onTriggered: IdleInhibitorService.manualToggle()
        onSecondaryTriggered: panelRoot.toggleNativePanel("sessionMenuPanel")
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("settings")
        detailText: panelRoot.tr("openPanel")
        iconName: "settings"
        secondaryIcon: "adjustments-horizontal"
        secondaryTooltip: panelRoot.tr("dashboardSettings")
        onTriggered: {
          const panel = PanelService.getPanel("settingsPanel", panelRoot.activeScreen);
          if (panel) {
            panel.requestedTab = SettingsPanel.Tab.General;
            panel.open();
          }
        }
        onSecondaryTriggered: panelRoot.openDashboardSettings()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("wallpapers")
        detailText: panelRoot.tr("openPanel")
        iconName: "wallpaper-selector"
        secondaryIcon: Settings.data.colorSchemes.darkMode ? "sun" : "moon"
        secondaryTooltip: Settings.data.colorSchemes.darkMode ? panelRoot.tr("switchToLightMode") : panelRoot.tr("switchToDarkMode")
        onTriggered: panelRoot.openWallpaperSelector()
        onSecondaryTriggered: Settings.data.colorSchemes.darkMode = !Settings.data.colorSchemes.darkMode
      }
    }

    GridLayout {
      Layout.fillWidth: true
      visible: quickActionsCard.toolsTabIndex === 1
      columns: 2
      columnSpacing: Style.marginS
      rowSpacing: Style.marginS

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolColorPicker")
        detailText: panelRoot.tr("openPanel")
        iconName: "color-picker"
        onTriggered: ScreenToolkitService.colorPicker()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolPalette")
        detailText: panelRoot.tr("openPanel")
        iconName: "palette"
        onTriggered: ScreenToolkitService.palette()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolOcr")
        detailText: panelRoot.tr("openPanel")
        iconName: "scan"
        onTriggered: ScreenToolkitService.ocr()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolQr")
        detailText: panelRoot.tr("openPanel")
        iconName: "qrcode"
        onTriggered: ScreenToolkitService.qr()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolLens")
        detailText: panelRoot.tr("openPanel")
        iconName: "world-search"
        onTriggered: ScreenToolkitService.lens()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolAnnotate")
        detailText: panelRoot.tr("openPanel")
        iconName: "brush"
        onTriggered: ScreenToolkitService.annotateFullscreen()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolMeasure")
        detailText: panelRoot.tr("openPanel")
        iconName: "ruler"
        onTriggered: ScreenToolkitService.measure()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolPin")
        detailText: panelRoot.tr("openPanel")
        iconName: "pin"
        onTriggered: ScreenToolkitService.pin()
      }

      ActionTile {
        panelRoot: quickActionsCard.panelRoot
        labelText: panelRoot.tr("toolMirror")
        detailText: (quickActionsCard.screenToolkitMain?.mirrorVisible ?? false) ? panelRoot.tr("enabled") : panelRoot.tr("openPanel")
        iconName: "camera"
        active: quickActionsCard.screenToolkitMain?.mirrorVisible ?? false
        onTriggered: ScreenToolkitService.mirror()
      }
    }
  }
}
