import QtQuick
import qs.Commons

// Outer surface: shared wallpaper, a legible palette veil and material finish.
// Content remains a sibling of these paints; it is never blurred or faded.
Item {
  id: root
  property color color: HydraColor.mSurfaceContainer
  property real backgroundOpacity: 1
  property alias radius: paint.radius
  property alias border: legacyBorder.border
  property alias topLeftRadius: paint.topLeftRadius
  property alias topRightRadius: paint.topRightRadius
  property alias bottomLeftRadius: paint.bottomLeftRadius
  property alias bottomRightRadius: paint.bottomRightRadius
  readonly property real materialAlpha: Style.customMaterial ? (Style.profileUsesGlass && glass.ready ? glass.tintOpacity : 1) : backgroundOpacity

  NGlassBackdrop {
    id: glass
    anchors.fill: parent
    visible: root.color.a > 0 && root.backgroundOpacity > 0
    maskSource: mask
    surfaceColor: Style.materialColor(root.color)
    tintOpacity: Style.glassSurfaceOpacity(surfaceColor)
  }

  Rectangle {
    id: mask
    anchors.fill: parent
    visible: false
    color: Qt.rgba(1, 1, 1, 1)
    radius: paint.radius
    topLeftRadius: paint.topLeftRadius
    topRightRadius: paint.topRightRadius
    bottomLeftRadius: paint.bottomLeftRadius
    bottomRightRadius: paint.bottomRightRadius
  }

  Rectangle {
    id: legacyBorder
    visible: false
    color: "transparent"
    border.width: 0
  }

  Rectangle {
    id: paint
    anchors.fill: parent
    color: root.color.a === 0 || root.backgroundOpacity === 0 ? "transparent" : Qt.alpha(Style.materialColor(root.color), (Style.customMaterial ? 1 : root.color.a) * root.materialAlpha)
    border.color: Style.customMaterial ? (root.color.a === 0 || root.backgroundOpacity === 0 ? "transparent" : Style.materialEdgeColor) : legacyBorder.border.color
    border.width: Style.customMaterial ? Style.borderS : legacyBorder.border.width
  }

  NMaterialFinish {
    anchors.fill: parent
    visible: root.color.a > 0 && root.backgroundOpacity > 0
    maskSource: mask
    surfaceColor: Style.materialColor(root.color)
  }
}
