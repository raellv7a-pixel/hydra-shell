pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.UI

Item {
  id: root
  required property Item maskSource
  readonly property bool effectsSupported: GraphicsInfo.api !== GraphicsInfo.Software
  property real tintOpacity: Style.glassBodyOpacity
  property color surfaceColor: Style.materialColor(HydraColor.mSurfaceContainer)
  readonly property vector2d backdropBounds: Style.glassBackdropBounds(surfaceColor, tintOpacity)
  readonly property var window: QsWindow.window
  readonly property var host: QsWindow.contentItem
  readonly property var entry: GlassBackdropService.find(host)
  readonly property Item backdrop: entry?.source ?? null
  readonly property bool available: root.visible && (window?.visible ?? false) && tintOpacity < 1 && Style.profileUsesGlass && Style.glassEffectsEnabled && effectsSupported && (backdrop?.ready ?? false)
  readonly property bool ready: available && (renderLoader.item?.healthy ?? true)
  readonly property matrix4x4 backdropTransform: {
    sceneTransform.transform;
    root.window?.windowTransform;
    // Also track reparenting: TransformWatcher rebuilds its chain without
    // emitting transformChanged when only a parent changes.
    for (let ancestor = root; ancestor; ancestor = ancestor.parent) {}
    const screenX = root.window?.screen?.x ?? 0;
    const screenY = root.window?.screen?.y ?? 0;
    const origin = root.mapFromGlobal(screenX, screenY);
    const unitX = root.mapFromGlobal(screenX + 1, screenY);
    const unitY = root.mapFromGlobal(screenX, screenY + 1);
    return Qt.matrix4x4(unitX.x - origin.x, unitY.x - origin.x, 0, origin.x, unitX.y - origin.y, unitY.y - origin.y, 0, origin.y, 0, 0, 1, 0, 0, 0, 0, 1);
  }

  Component.onDestruction: GlassBackdropService.unregisterSource(root)
  onHostChanged: Qt.callLater(() => {
    GlassBackdropService.unregisterSource(root);
    if (sourceLoader.active && sourceLoader.status === Loader.Ready)
      GlassBackdropService.registerSource(root.host, root, sourceLoader.item);
  })

  TransformWatcher {
    id: sceneTransform
    a: root.host
    b: root
  }

  Loader {
    id: sourceLoader
    active: root.visible && (root.window?.visible ?? false) && Settings.data.wallpaper.enabled && root.tintOpacity < 1 && Style.profileUsesGlass && Style.glassEffectsEnabled && root.effectsSupported && root.host !== null && (!root.entry || root.entry.owner === root)
    sourceComponent: NGlassSource {
      screen: root.window?.screen ?? null
    }
    onLoaded: Qt.callLater(() => {
      if (sourceLoader.active && sourceLoader.status === Loader.Ready)
        GlassBackdropService.registerSource(root.host, root, sourceLoader.item);
    })
    onActiveChanged: Qt.callLater(() => {
      if (!sourceLoader.active)
        GlassBackdropService.unregisterSource(root);
    })
  }

  Loader {
    id: renderLoader
    anchors.fill: parent
    active: root.available
    sourceComponent: Item {
      readonly property bool healthy: wallpaperShader.status !== ShaderEffect.Error
      ShaderEffectSource {
        id: silhouette
        sourceItem: root.ready ? root.maskSource : null
        hideSource: false
        live: true
        visible: false
      }

      Item {
        id: wallpaperCut
        anchors.fill: parent
        visible: root.ready
        ShaderEffect {
          id: wallpaperShader
          transform: Matrix4x4 {
            matrix: root.backdropTransform
          }
          width: root.backdrop?.width ?? 1
          height: root.backdrop?.height ?? 1
          property variant source: root.backdrop?.texture ?? null
          property variant maskTexture: silhouette
          property vector2d toneBounds: root.backdropBounds
          property vector2d sourceSize: Qt.vector2d(root.backdrop?.width ?? 1, root.backdrop?.height ?? 1)
          property vector2d maskSize: Qt.vector2d(root.width, root.height)
          property matrix4x4 maskFromSource: root.backdropTransform
          property matrix4x4 sourceFromMask: root.backdropTransform.inverted()
          property real refractionAmount: Style.materialRefractionAmount
          property real saturation: Style.materialSaturation
          fragmentShader: Quickshell.shellPath("Shaders/qsb/tinted_glass.frag.qsb")
        }
      }

      ShaderEffectSource {
        id: cutTexture
        sourceItem: root.ready ? wallpaperCut : null
        hideSource: true
        live: true
        visible: false
      }

      MultiEffect {
        anchors.fill: parent
        visible: root.ready
        source: cutTexture
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: silhouette
        maskThresholdMin: 0
        maskSpreadAtMin: 0
        maskThresholdMax: 1
        maskSpreadAtMax: 0
      }
    }
  }
}
