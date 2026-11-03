import QtQuick
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property string icon: ""
  property real size: Style.baseWidgetSize * Style.uiScaleRatio

  readonly property var artwork: ColoredIcons.get(root.icon)
  readonly property color tileColor: root.artwork ? ColoredIcons.identity[root.artwork.tint] : ColoredIcons.identity.gray
  readonly property bool materialVisible: root.artwork !== null && ColoredIcons.fontReady
  readonly property real glyphSize: Math.round(Math.min(root.width, root.height) * ColoredIcons.glyphShare)

  implicitWidth: root.size
  implicitHeight: root.size
  visible: root.icon !== ""
  radius: Math.round(Math.min(root.width, root.height) * ColoredIcons.cornerRatio)
  Accessible.ignored: true

  gradient: Gradient {
    GradientStop {
      position: 0
      color: Qt.lighter(root.tileColor, ColoredIcons.gradientLift)
    }
    GradientStop {
      position: 1
      color: root.tileColor
    }
  }

  Text {
    anchors.fill: parent
    visible: root.materialVisible
    text: root.materialVisible ? root.artwork.glyph : ""
    color: ColoredIcons.glyphColor
    font.family: ColoredIcons.fontFamily
    font.pixelSize: root.glyphSize
    font.weight: Font.Normal
    font.hintingPreference: Font.PreferNoHinting
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  // Unmapped keys retain their actual Tabler artwork. This also keeps mapped
  // icons legible while the bundled font loads or if its source cannot load.
  NIcon {
    anchors.fill: parent
    visible: !root.materialVisible
    icon: root.materialVisible ? "" : (root.artwork?.fallback ?? root.icon)
    color: ColoredIcons.glyphColor
    applyUiScale: false
    pointSize: root.glyphSize * 72 / (Screen.logicalPixelDensity * 25.4)
  }
}
