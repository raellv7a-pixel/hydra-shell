import QtQuick
import Quickshell
import qs.Services.System

Item {
  id: root

  property real spriteSize: 96
  readonly property bool sheetSprite: TamagotchiService.petState !== "sleeping"
  readonly property int frameIndex: TamagotchiService.isDirty
    ? (TamagotchiService.eating ? 3 : 2)
    : (TamagotchiService.eating ? 1 : 0)
  readonly property string spriteFile: {
    switch (TamagotchiService.petState) {
    case "angry": return "sapo_angry.png";
    case "hungry": return "sapo_hungry.png";
    case "sad": return "sapo_sad.png";
    case "sleeping": return "sapo_sleeping.png";
    case "tired": return "sapo_tired.png";
    default: return "sapo_idle.png";
    }
  }
  readonly property url assetDirectory: Qt.resolvedUrl(Quickshell.shellDir + "/Assets/Icons/Tamagotchi/")

  implicitWidth: spriteSize
  implicitHeight: spriteSize

  Image {
    anchors.fill: parent
    source: root.assetDirectory + root.spriteFile
    sourceSize: root.sheetSprite ? Qt.size(160, 40) : Qt.size(40, 40)
    sourceClipRect: root.sheetSprite ? Qt.rect(root.frameIndex * 40, 0, 40, 40) : Qt.rect(0, 0, 40, 40)
    fillMode: Image.PreserveAspectFit
    smooth: false
    Accessible.ignored: true
  }

  Image {
    anchors.fill: parent
    source: root.assetDirectory + "flies.png"
    sourceSize: Qt.size(40, 40)
    fillMode: Image.PreserveAspectFit
    smooth: false
    visible: TamagotchiService.isDirty && TamagotchiService.petState !== "angry" && TamagotchiService.petState !== "sleeping"
    Accessible.ignored: true
  }
}
