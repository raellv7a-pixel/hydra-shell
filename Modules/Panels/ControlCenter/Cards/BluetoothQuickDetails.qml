import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Modules.Panels.Settings.Tabs.Connections as ConnectionSettings
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  required property var panelRoot
  signal back

  // The list component owns pairing, connection, device status and battery UI.
  // Discovery belongs to this view, not to the settings tab's lifetime.
  property bool startedDiscovery: false
  function syncDiscovery() {
    if (visible && BluetoothService.enabled && !BluetoothService.scanningActive) {
      BluetoothService.setScanActive(true);
      startedDiscovery = true;
    } else if ((!visible || !BluetoothService.enabled) && startedDiscovery) {
      BluetoothService.setScanActive(false);
      startedDiscovery = false;
    }
  }
  onVisibleChanged: syncDiscovery()
  Connections {
    target: BluetoothService
    function onEnabledChanged() { root.syncDiscovery(); }
  }
  Component.onDestruction: {
    if (startedDiscovery)
      BluetoothService.setScanActive(false);
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginS

    // Fixed Header mirroring PerformanceDetailsCard
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * root.panelRoot.panelUnit)
        tooltipText: root.panelRoot.tr("back")
        onClicked: root.back()
      }

      NText {
        Layout.fillWidth: true
        text: root.panelRoot.tr("bluetooth")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NToggle {
        checked: BluetoothService.enabled
        enabled: BluetoothService.bluetoothAvailable && !NetworkService.airplaneModeEnabled && !BluetoothService.blocked
        onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIconButton {
        icon: BluetoothService.scanningActive ? "refresh" : "search"
        baseSize: Math.round(30 * root.panelRoot.panelUnit)
        tooltipText: I18n.tr("bluetooth.panel.scanning")
        enabled: BluetoothService.enabled
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mSurfaceContainerHighest
        colorFg: Color.mOnSurface
        onClicked: BluetoothService.setScanActive(true)
      }

      NIconButton {
        icon: Settings.data.network.bluetoothAutoConnect ? "bluetooth-connected" : "bluetooth"
        baseSize: Math.round(30 * root.panelRoot.panelUnit)
        tooltipText: Settings.data.network.bluetoothAutoConnect ? I18n.tr("tooltips.bluetooth-auto-connect-on") : I18n.tr("tooltips.bluetooth-auto-connect-off")
        colorBg: Settings.data.network.bluetoothAutoConnect ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh
        colorBgHover: Settings.data.network.bluetoothAutoConnect ? Qt.alpha(Color.mPrimaryContainer, 0.8) : Color.mSurfaceContainerHighest
        colorFg: Settings.data.network.bluetoothAutoConnect ? Color.mOnPrimaryContainer : Color.mOnSurface
        onClicked: Settings.data.network.bluetoothAutoConnect = !Settings.data.network.bluetoothAutoConnect
      }

      NIconButton {
        icon: "settings"
        baseSize: Math.round(30 * root.panelRoot.panelUnit)
        tooltipText: I18n.tr("tooltips.open-settings")
        colorBg: Color.mSurfaceContainerHigh
        colorBgHover: Color.mSurfaceContainerHighest
        colorFg: Color.mOnSurface
        onClicked: SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 1, root.panelRoot.activeScreen)
      }
      Item {
        Layout.fillWidth: true
      }
    }


    // Bounded Scroll
    NScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      reserveScrollbarSpace: false

      ColumnLayout {
        width: parent.width
        spacing: Style.marginS

        NText {
          visible: !BluetoothService.enabled
          Layout.fillWidth: true
          text: I18n.tr("bluetooth.panel.enable-message")
          wrapMode: Text.WordWrap
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          Layout.topMargin: Style.marginL
        }

        ConnectionSettings.BluetoothSubTab {
          id: bluetoothSubTab
          visible: BluetoothService.enabled
          Layout.fillWidth: true
          showOnlyLists: true
          dashboardMode: true
          panelUnit: root.panelRoot.panelUnit
        }

        NText {
          visible: BluetoothService.enabled && BluetoothService.adapter && BluetoothService.adapter.devices && BluetoothService.adapter.devices.values.length === 0
          text: BluetoothService.scanningActive ? I18n.tr("bluetooth.panel.scanning") : I18n.tr("bluetooth.panel.no-devices")
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          Layout.topMargin: Style.marginL
        }
      }
    }
  }
}
