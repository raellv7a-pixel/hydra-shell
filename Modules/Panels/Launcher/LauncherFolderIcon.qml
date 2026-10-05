import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root
  required property var folder
  property real iconSize: Settings.data.appLauncher.folderIconSize
  readonly property var semanticNames: ({ tools: ["applications-utilities", "applications-system"], productivity: ["applications-office"], creativity: ["applications-graphics"], social: ["applications-internet"], games: ["applications-games"], media: ["applications-multimedia"] })
  readonly property var manualNames: ({ folder: "folder", briefcase: "folder-documents", code: "applications-development", palette: "applications-graphics", music: "folder-music", users: "folder-publicshare", "device-gamepad": "applications-games", star: "folder-favorites" })
  readonly property string systemSource: {
    if (Settings.data.appLauncher.folderIconSource !== "system") return "";
    const names = folder.mode === "smart" ? semanticNames[folder.id] || [] : [manualNames[folder.icon] || folder.icon || "folder"];
    for (const name of names) {
      const source = Quickshell.iconPath(name, true);
      if (source) return source;
    }
    return "";
  }
  readonly property bool useSystem: systemSource !== "" && systemImage.status !== Image.Error
  readonly property bool illustrated: folder.mode === "smart" || !folder.icon || folder.icon === "folder" || !manualNames[folder.icon] || (Settings.data.appLauncher.folderIconSource === "system" && !useSystem)
  implicitWidth: Math.round(Math.max(24, Math.min(48, iconSize)) * Style.uiScaleRatio)
  implicitHeight: implicitWidth
  Accessible.ignored: true
  Image {
    id: systemImage
    anchors.fill: parent
    source: root.systemSource
    visible: root.useSystem
    sourceSize: Qt.size(width, height)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
  }
  Image {
    anchors.fill: parent
    visible: !root.useSystem && root.illustrated
    source: Qt.resolvedUrl("../../../Assets/Launcher/Folders/" + (root.folder.mode === "smart" ? root.folder.id : "folder") + ".svg")
    sourceSize: Qt.size(width, height)
    asynchronous: true
  }
  NIcon {
    anchors.centerIn: parent
    visible: !root.useSystem && !root.illustrated
    icon: root.illustrated || root.useSystem ? "folder" : root.folder.icon || "folder"
    pointSize: root.iconSize * Style.uiScaleRatio * 0.75
    color: Color.mPrimary
  }
}
