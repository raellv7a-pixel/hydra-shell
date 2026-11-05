import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

Item {
  id: root
  // Texture producer only: no intermediate pass may paint outside a surface mask.
  visible: false
  property var screen: null
  property string wallpaper: ""
  readonly property bool ready: enabledWallpaper && image.status === Image.Ready && mapped.status !== ShaderEffect.Error && (!nativeSizeMode || nativeWidth > 0 && nativeHeight > 0)
  readonly property Item texture: Style.glassBlurAmount > 0 ? blurredTexture : mappedTexture
  readonly property bool enabledWallpaper: !!screen && Settings.data.wallpaper.enabled && !!wallpaper && !WallpaperService.isSolidColorPath(wallpaper) && !/\.(webm|mp4|mkv|mov)$/i.test(wallpaper)
  readonly property real fillMode: {
    // Keep the setting dependency explicit, including before the model is initialized.
    const mode = Settings.data.wallpaper.fillMode;
    return WallpaperService.getFillModeUniform();
  }
  readonly property bool nativeSizeMode: fillMode < 0.5 || fillMode > 3.5
  readonly property size halfSize: Qt.size(Math.max(1, Math.round(width / 2)), Math.max(1, Math.round(height / 2)))
  readonly property real outputScale: screen ? CompositorService.getDisplayScale(screen.name) : 1
  readonly property size sampleSize: Style.glassBlurAmount > 0 ? halfSize : Qt.size(Math.max(1, Math.round(width * outputScale)), Math.max(1, Math.round(height * outputScale)))
  property string imagePath: ""
  property int nativeWidth: 0
  property int nativeHeight: 0
  property var requestState: ({ alive: true, id: 0 })
  width: screen?.width ?? 1
  height: screen?.height ?? 1

  function refresh() {
    wallpaper = screen ? WallpaperService.getWallpaper(screen.name) || "" : "";
  }
  onScreenChanged: {
    refresh();
    Qt.callLater(prepareImage);
  }
  onEnabledWallpaperChanged: Qt.callLater(prepareImage)
  onNativeSizeModeChanged: Qt.callLater(prepareImage)
  onWidthChanged: Qt.callLater(prepareImage)
  onHeightChanged: Qt.callLater(prepareImage)
  onWallpaperChanged: Qt.callLater(prepareImage)
  Component.onCompleted: refresh()
  Component.onDestruction: requestState.alive = false

  function prepareImage() {
    const state = requestState;
    const request = ++state.id;
    imagePath = "";
    nativeWidth = 0;
    nativeHeight = 0;
    if (!enabledWallpaper || !ImageCacheService.initialized)
      return;

    const path = wallpaper;
    const scale = CompositorService.getDisplayScale(screen.name);
    // Match the desktop's cached image dimensions, not the half-resolution decode.
    ImageCacheService.getLarge(path, Math.round(width * scale), Math.round(height * scale), function (cachedPath, success) {
      if (!state.alive || request !== state.id)
        return;
      const sourcePath = success ? cachedPath : path;
      if (!root.nativeSizeMode) {
        root.imagePath = sourcePath;
        return;
      }
      ImageCacheService.getImageDimensions(sourcePath, function (imageWidth, imageHeight) {
        if (!state.alive || request !== state.id || imageWidth <= 0 || imageHeight <= 0)
          return;
        root.nativeWidth = imageWidth;
        root.nativeHeight = imageHeight;
        root.imagePath = sourcePath;
      });
    });
  }

  Connections {
    target: ImageCacheService
    function onInitializedChanged() {
      Qt.callLater(root.prepareImage);
    }
  }

  Connections {
    target: CompositorService
    function onDisplayScalesChanged() {
      Qt.callLater(root.prepareImage);
    }
  }

  Connections {
    target: Settings.data.wallpaper
    function onUseOriginalImagesChanged() {
      Qt.callLater(root.prepareImage);
    }
  }

  Connections {
    target: WallpaperService
    function onIsInitializedChanged() {
      root.refresh();
    }
    function onWallpaperProcessingComplete(screenName, path, cachedPath) {
      if (screenName === root.screen?.name)
        root.wallpaper = path;
    }
    function onWallpaperChanged(screenName, path) {
      if (screenName === root.screen?.name)
        root.wallpaper = path;
    }
  }

  Image {
    id: image
    visible: false
    source: root.enabledWallpaper ? root.imagePath : ""
    sourceSize: root.nativeSizeMode ? Qt.size(Math.max(1, Math.round(root.nativeWidth / (Style.glassBlurAmount > 0 ? 2 : 1))), Math.max(1, Math.round(root.nativeHeight / (Style.glassBlurAmount > 0 ? 2 : 1)))) : root.sampleSize
    fillMode: Image.Stretch
    asynchronous: true
    cache: true
  }

  ShaderEffect {
    id: mapped
    anchors.fill: parent
    visible: root.ready
    property variant source1: image
    property variant source2: image
    property real progress: 0
    property real fillMode: root.fillMode
    property vector4d fillColor: Qt.vector4d(Settings.data.wallpaper.fillColor.r, Settings.data.wallpaper.fillColor.g, Settings.data.wallpaper.fillColor.b, 1)
    property real imageWidth1: Math.max(1, root.nativeSizeMode ? root.nativeWidth : image.implicitWidth)
    property real imageHeight1: Math.max(1, root.nativeSizeMode ? root.nativeHeight : image.implicitHeight)
    property real imageWidth2: imageWidth1
    property real imageHeight2: imageHeight1
    property real screenWidth: root.width
    property real screenHeight: root.height
    property real isSolid1: 0
    property real isSolid2: 0
    property vector4d solidColor1: Qt.vector4d(0, 0, 0, 1)
    property vector4d solidColor2: solidColor1
    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_fade.frag.qsb")
  }

  ShaderEffectSource {
    id: mappedTexture
    sourceItem: root.ready ? mapped : null
    textureSize: root.sampleSize
    hideSource: true
    live: true
    visible: false
  }

  MultiEffect {
    id: blurred
    anchors.fill: parent
    visible: root.ready && Style.glassBlurAmount > 0
    source: root.ready && Style.glassBlurAmount > 0 ? mappedTexture : null
    autoPaddingEnabled: false
    blurEnabled: root.ready && Style.glassBlurAmount > 0
    blur: Style.glassBlurAmount
    blurMax: 64
  }

  ShaderEffectSource {
    id: blurredTexture
    sourceItem: root.ready && Style.glassBlurAmount > 0 ? blurred : null
    textureSize: root.halfSize
    hideSource: true
    live: true
    visible: false
  }
}
