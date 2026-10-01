import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
  clip: true

  property int toolsTabIndex: 0
  readonly property var screenToolkitMain: ScreenToolkitService.mainInstance

  readonly property var toolItems: [
    {
      labelText: panelRoot.tr("toolColorPicker"),
      detailText: panelRoot.tr("openPanel"),
      iconName: "color-picker",
      active: false,
      onTriggered: function () {
        ScreenToolkitService.colorPicker();
      }
    },
    {
      labelText: panelRoot.tr("toolPalette"),
      detailText: panelRoot.tr("openPanel"),
      iconName: "palette",
      active: false,
      onTriggered: function () {
        ScreenToolkitService.palette();
      }
    },
    {
      labelText: panelRoot.tr("toolOcr"),
      detailText: panelRoot.tr("openPanel"),
      iconName: "scan",
      active: false,
      onTriggered: function () {
        ScreenToolkitService.ocr();
      }
    },
    {
      labelText: panelRoot.tr("toolQr"),
      detailText: panelRoot.tr("openPanel"),
      iconName: "qrcode",
      active: false,
      onTriggered: function () {
        ScreenToolkitService.qr();
      }
    },
    {
      labelText: panelRoot.tr("toolLens"),
      detailText: panelRoot.tr("openPanel"),
      iconName: "world-search",
      active: false,
      onTriggered: function () {
        ScreenToolkitService.lens();
      }
    },
    {
      labelText: panelRoot.tr("toolAnnotate"),
      detailText: panelRoot.tr("openPanel"),
      iconName: "brush",
      active: false,
      onTriggered: function () {
        ScreenToolkitService.annotateFullscreen();
      }
    },
    {
      labelText: panelRoot.tr("toolMeasure"),
      detailText: panelRoot.tr("openPanel"),
      iconName: "ruler",
      active: false,
      onTriggered: function () {
        ScreenToolkitService.measure();
      }
    },
    {
      labelText: panelRoot.tr("toolPin"),
      detailText: panelRoot.tr("openPanel"),
      iconName: "pin",
      active: false,
      onTriggered: function () {
        ScreenToolkitService.pin();
      }
    },
    {
      labelText: panelRoot.tr("toolMirror"),
      detailText: (quickActionsCard.screenToolkitMain?.mirrorVisible ?? false) ? panelRoot.tr("enabled") : panelRoot.tr("openPanel"),
      iconName: "camera",
      active: quickActionsCard.screenToolkitMain?.mirrorVisible ?? false,
      onTriggered: function () {
        ScreenToolkitService.mirror();
      }
    }
  ]

  readonly property int toolsPerPage: 8
  readonly property int toolsPageCount: Math.max(1, Math.ceil(toolItems.length / toolsPerPage))
  property int toolsCurrentPage: 0
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
        active: PowerProfileService.hydraPerformanceMode
        onTriggered: PowerProfileService.toggleHydraPerformance()
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
        onTriggered: panelRoot.openShellSettings()
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

    Item {
      id: toolsContainer
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: quickActionsCard.toolsTabIndex === 1
      clip: true

      SwipeView {
        id: toolsSwipe
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: toolsDots.visible ? toolsDots.top : parent.bottom
        anchors.bottomMargin: toolsDots.visible ? Math.round(4 * quickActionsCard.panelRoot.panelUnit) : 0
        clip: true
        currentIndex: quickActionsCard.toolsCurrentPage
        onCurrentIndexChanged: quickActionsCard.toolsCurrentPage = currentIndex

        Repeater {
          model: quickActionsCard.toolsPageCount

          Item {
            id: pageWrapper
            required property int index

            GridLayout {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              columns: 2
              columnSpacing: Style.marginS
              rowSpacing: Math.round(4 * quickActionsCard.panelRoot.panelUnit)

              Repeater {
                model: {
                  const start = pageWrapper.index * quickActionsCard.toolsPerPage;
                  return quickActionsCard.toolItems.slice(start, start + quickActionsCard.toolsPerPage);
                }

                ActionTile {
                  required property var modelData
                  panelRoot: quickActionsCard.panelRoot
                  Layout.fillWidth: true
                  Layout.preferredHeight: Math.round(62 * panelRoot.panelUnit)
                  labelText: modelData.labelText
                  detailText: modelData.detailText
                  iconName: modelData.iconName
                  active: modelData.active
                  onTriggered: modelData.onTriggered()
                }
              }

              // Placeholder keeps 50% width per column if page has an odd number of items
              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(62 * quickActionsCard.panelRoot.panelUnit)
                visible: {
                  const start = pageWrapper.index * quickActionsCard.toolsPerPage;
                  const countOnPage = Math.min(quickActionsCard.toolsPerPage, quickActionsCard.toolItems.length - start);
                  return countOnPage % 2 !== 0;
                }
              }
            }
          }
        }
      }

      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: quickActionsCard.toolsPageCount > 1
        onWheel: event => {
                   if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
                     toolsSwipe.currentIndex = Math.min(quickActionsCard.toolsPageCount - 1, toolsSwipe.currentIndex + 1);
                   } else if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
                     toolsSwipe.currentIndex = Math.max(0, toolsSwipe.currentIndex - 1);
                   }
                   event.accepted = true;
                 }
      }

      PageDots {
        id: toolsDots
        panelRoot: quickActionsCard.panelRoot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        count: quickActionsCard.toolsPageCount
        currentIndex: quickActionsCard.toolsCurrentPage
        onSelected: index => quickActionsCard.toolsCurrentPage = index
      }
    }
  }
}
