import QtQuick
import qs.Widgets

NSettingsGroupPage {
  pageKey: "audio"
  groups: [
    { key: "volumes", labelKey: "common.volumes", icon: "volume", content: volumesContent },
    { key: "devices", labelKey: "common.devices", icon: "devices", content: devicesContent },
    { key: "media", labelKey: "common.media", icon: "music", content: mediaContent },
    { key: "visualizer", labelKey: "common.visualizer", icon: "activity", content: visualizerContent }
  ]

  Component { id: volumesContent; VolumesSubTab {} }
  Component { id: devicesContent; DevicesSubTab {} }
  Component { id: mediaContent; MediaSubTab {} }
  Component { id: visualizerContent; VisualizerSubTab {} }
}
