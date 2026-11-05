pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons

// A transparent paint over the material, never a capture of its content.
Item {
  id: root
  required property Item maskSource
  property color surfaceColor: Style.materialColor(HydraColor.mSurfaceContainer)
  readonly property var window: QsWindow.window
  readonly property Item host: QsWindow.contentItem
  readonly property vector2d toneBounds: Style.glassBackdropBounds(surfaceColor, 0)
  readonly property bool hasFinish: Style.materialLightAmount > 0 || Style.materialChromeAmount > 0 || Style.materialTextureAmount > 0 || Style.materialBloomAmount > 0 || Style.materialAuroraAmount > 0 || Style.materialPaperAmount > 0
  readonly property bool onScreen: {
    sceneTransform.transform;
    if (!host || width <= 0 || height <= 0)
      return false;
    const rect = root.mapToItem(host, 0, 0, width, height);
    return rect.x < host.width && rect.y < host.height && rect.x + rect.width > 0 && rect.y + rect.height > 0;
  }
  Accessible.ignored: true

  TransformWatcher {
    id: sceneTransform
    a: root.host
    b: root
  }

  Loader {
    anchors.fill: parent
    active: root.visible && (root.window?.visible ?? false) && root.onScreen && root.maskSource !== null && root.surfaceColor.a > 0 && root.hasFinish && Style.materialEffectsEnabled && GraphicsInfo.api !== GraphicsInfo.Software && root.toneBounds.x <= root.toneBounds.y
    sourceComponent: Item {
      ShaderEffectSource {
        id: silhouette
        sourceItem: root.maskSource
        hideSource: false
        live: true
        smooth: true
        visible: false
      }

      ShaderEffect {
        anchors.fill: parent
        visible: status !== ShaderEffect.Error
        property variant maskTexture: silhouette
        property vector2d surfaceSize: Qt.vector2d(root.width, root.height)
        property vector2d toneBounds: root.toneBounds
        property color surfaceColor: root.surfaceColor
        property color inkColor: HydraColor.mOnSurface
        property color primaryColor: Style.materialHighlightColor
        property color tertiaryColor: HydraColor.mTertiary
        property real lightAmount: Style.materialLightAmount
        property real chromeAmount: Style.materialChromeAmount
        property real textureAmount: Style.materialTextureAmount
        property real bloomAmount: Style.materialBloomAmount
        property real auroraAmount: Style.materialAuroraAmount
        property real paperAmount: Style.materialPaperAmount
        property real pixelScale: Style.uiScaleRatio
        fragmentShader: Quickshell.shellPath("Shaders/qsb/material_finish.frag.qsb")
      }
    }
  }
}
