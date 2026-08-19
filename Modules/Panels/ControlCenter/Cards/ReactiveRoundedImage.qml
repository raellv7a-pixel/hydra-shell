import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets
Item {
  id: reactiveImage

  property real radius: 0
  property string imagePath: ""
  property string fallbackIcon: ""
  property real fallbackIconSize: Style.fontSizeXXL
  property bool animatedPlaying: true
  property bool framed: true
  property int imageFillMode: Image.PreserveAspectCrop

  readonly property bool isAnimated: imagePath.toLowerCase().endsWith(".gif")
  readonly property Item imageSource: imageSourceLoader.item
  readonly property bool showFallback: fallbackIcon !== "" && (imagePath === "" || (imageSource && imageSource.status === Image.Error))
  readonly property int status: imageSource ? imageSource.status : Image.Null

  Rectangle {
    anchors.fill: parent
    radius: reactiveImage.radius
    color: (reactiveImage.framed || reactiveImage.showFallback) ? Qt.alpha(Color.mSurface, 0.28) : "transparent"
    border.width: (reactiveImage.framed || reactiveImage.showFallback) ? Style.borderS : 0
    border.color: Qt.alpha(Color.mOutline, 0.18)

    Loader {
      id: imageSourceLoader
      anchors.fill: parent
      active: reactiveImage.imagePath !== ""
      sourceComponent: reactiveImage.isAnimated ? animatedImageComponent : staticImageComponent
    }

    Component {
      id: staticImageComponent
      Image {
        visible: false
        source: reactiveImage.imagePath
        mipmap: true
        smooth: true
        asynchronous: true
        antialiasing: true
        fillMode: reactiveImage.imageFillMode
      }
    }

    Component {
      id: animatedImageComponent
      AnimatedImage {
        visible: false
        source: reactiveImage.imagePath
        playing: reactiveImage.animatedPlaying
        mipmap: true
        smooth: true
        asynchronous: true
        antialiasing: true
        fillMode: reactiveImage.imageFillMode
      }
    }

    ShaderEffectSource {
      id: safeFallback
      sourceItem: Rectangle {
        width: 1
        height: 1
        color: "transparent"
      }
      visible: false
      live: false
    }

    ShaderEffect {
      anchors.fill: parent
      visible: !reactiveImage.showFallback && reactiveImage.imageSource !== null && reactiveImage.status === Image.Ready
      property var source: reactiveImage.imageSource ?? safeFallback
      property real itemWidth: width
      property real itemHeight: height
      property real sourceWidth: reactiveImage.imageSource?.sourceSize.width ?? 0
      property real sourceHeight: reactiveImage.imageSource?.sourceSize.height ?? 0
      property real cornerRadius: reactiveImage.radius
      property real imageOpacity: 1.0
      property int fillMode: reactiveImage.imageFillMode

      fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/rounded_image.frag.qsb")
      supportsAtlasTextures: false
      blending: true
    }

    NIcon {
      anchors.fill: parent
      visible: reactiveImage.showFallback
      icon: reactiveImage.fallbackIcon
      pointSize: reactiveImage.fallbackIconSize
      color: Color.mOnSurfaceVariant
    }
  }
}
