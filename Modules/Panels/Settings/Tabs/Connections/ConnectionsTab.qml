import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "connections"
  groups: [
    { key: "wifi", labelKey: "common.wifi", icon: "wifi", content: wifiContent },
    { key: "bluetooth", labelKey: "common.bluetooth", icon: "bluetooth", content: bluetoothContent }
  ]

  Component { id: wifiContent; WifiSubTab {} }
  Component { id: bluetoothContent; BluetoothSubTab {} }
}
