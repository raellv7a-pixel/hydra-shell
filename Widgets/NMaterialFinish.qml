pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons

// A transparent paint over the material, never a capture of its content.
Item {
  id: root
  required property Item maskSource
  property color surfaceColor: Style.materialColor(HydraColor.mSurfaceContainer)
  // Negative radii select an arbitrary path; rounded surfaces need no capture.
  property vector4d cornerRadii: Qt.vector4d(-1, -1, -1, -1)
  property real strength: 1
  readonly property bool rounded: cornerRadii.x >= 0
  readonly property real maskPadding: rounded ? 0 : Math.ceil(32 * Style.uiScaleRatio)
  readonly property color opaqueSurfaceColor: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 1)
  readonly property var window: QsWindow.window
  readonly property Item host: QsWindow.contentItem
  readonly property vector2d toneBounds: Style.glassBackdropBounds(opaqueSurfaceColor, 0)
  readonly property bool hasFinish: strength > 0 && (Style.materialEdgeAmount > 0 || Style.materialLightAmount > 0 || Style.materialChromeAmount > 0 || Style.materialTextureAmount > 0 || Style.materialBloomAmount > 0 || Style.materialAuroraAmount > 0 || Style.materialPaperAmount > 0)
  readonly property bool onScreen: {
    if (!visible || !hasFinish || !Style.materialEffectsEnabled)
      return false;
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
        sourceItem: root.rounded ? null : root.maskSource
        sourceRect: Qt.rect(-root.maskPadding, -root.maskPadding, root.width + 2 * root.maskPadding, root.height + 2 * root.maskPadding)
        textureSize: Qt.size(Math.ceil(root.width + 2 * root.maskPadding), Math.ceil(root.height + 2 * root.maskPadding))
        mipmap: true
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
        property color surfaceColor: root.opaqueSurfaceColor
        property color inkColor: HydraColor.mOnSurface
        property color primaryColor: Style.materialHighlightColor
        property color tertiaryColor: HydraColor.mTertiary
        property vector4d cornerRadii: root.cornerRadii
        property real maskPadding: root.maskPadding
        property real strength: root.strength
        property real edgeAmount: Style.materialEdgeAmount
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
