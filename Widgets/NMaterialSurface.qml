pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets.Iris

// Hydra host for the original iNiR field and light wash. Content is not captured.
Item {
  id: root
  property color color: HydraColor.mSurfaceContainer
  property real backgroundOpacity: 1
  property bool readingCards: false
  property alias radius: paint.radius
  property alias border: paint.border
  property alias topLeftRadius: paint.topLeftRadius
  property alias topRightRadius: paint.topRightRadius
  property alias bottomLeftRadius: paint.bottomLeftRadius
  property alias bottomRightRadius: paint.bottomRightRadius
  readonly property bool hasMaterialShadow: material.active && Settings.data.general.enableShadows

  TransformWatcher {
    id: placement
    a: root.QsWindow.contentItem
    b: root
  }

  Rectangle {
    id: paint
    anchors.fill: parent
    visible: !Style.customMaterial || !IrisStyle.effectsEnabled
    color: Style.customMaterial ? (root.color.a > 0 && root.backgroundOpacity > 0 ? IrisStyle.bodySurface : "transparent") : Qt.alpha(root.color, root.color.a * root.backgroundOpacity)
  }

  Loader {
    id: material
    active: Style.customMaterial && IrisStyle.effectsEnabled && root.color.a > 0 && root.backgroundOpacity > 0
    anchors.fill: parent
    sourceComponent: Item {
      IrisField {
        id: field
        x: -reach
        y: -reach
        width: root.width + 2 * reach
        height: root.height + 2 * reach
        tint: IrisStyle.bodySurface
        readonly property var origin: {
          void placement.transform;
          return IrisHostGeometry.scenePoint(root, field.x, field.y);
        }
        wallpaperAllowed: origin !== null
        sceneOrigin: origin ?? Qt.point(0, 0)
        sceneSize: Qt.size(root.QsWindow.window?.screen?.width ?? root.width,
                           root.QsWindow.window?.screen?.height ?? root.height)
        shapes: [{
          id: "surface", x: reach, y: reach,
          width: root.width, height: root.height,
          radius: paint.radius, fuse: 0, paints: false
        }]
      }
      IrisLightWash {
        anchors.fill: parent
        light: IrisStyle.accent
        radius: paint.radius
      }
      IrisReadingPlate {
        visible: !root.readingCards
        anchors.fill: parent
        radius: paint.radius
      }
    }
  }
}
