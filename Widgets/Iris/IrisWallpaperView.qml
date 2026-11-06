pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

// Hydra's NGlassSource wallpaper mapping/cache adapter, without its blur pass.
// IrisGlassSource owns the sole blur; a grade captures this view instead of a second mapped texture.
Item {
    id: root

    property var screen: null
    property bool live: true
    property bool provideTexture: false
    property size decodeSize: Qt.size(0, 0)
    property string wallpaper: ""
    property string imagePath: ""
    property int nativeWidth: 0
    property int nativeHeight: 0
    property var requestState: ({ alive: true, id: 0 })

    width: root.screen?.width ?? 0
    height: root.screen?.height ?? 0

    readonly property bool isSolid: WallpaperService.isSolidColorPath(root.wallpaper)
    readonly property color solidColor: root.isSolid ? WallpaperService.getSolidColor(root.wallpaper) : "transparent"
    // Hydra's shared glass source does not mirror video frames; never substitute a still for them.
    readonly property bool isVideo: /\.(webm|mp4|mkv|mov)$/i.test(root.wallpaper)
    readonly property bool enabledWallpaper: !!root.screen && Settings.data.wallpaper.enabled && !!root.wallpaper && !root.isVideo
    readonly property bool ready: root.enabledWallpaper && (root.isSolid || (image.status === Image.Ready
        && mapped.status !== ShaderEffect.Error && (!root.nativeSizeMode || root.nativeWidth > 0 && root.nativeHeight > 0)))
    readonly property Item textureItem: mappedTexture
    readonly property real fillMode: {
        const mode = Settings.data.wallpaper.fillMode;
        return WallpaperService.getFillModeUniform();
    }
    readonly property bool nativeSizeMode: root.fillMode < 0.5 || root.fillMode > 3.5
    readonly property size captureSize: root.decodeSize.width > 0 && root.decodeSize.height > 0 ? root.decodeSize
        : Qt.size(Math.max(1, Math.round(root.width)), Math.max(1, Math.round(root.height)))

    function refresh() {
        root.wallpaper = root.screen ? WallpaperService.getWallpaper(root.screen.name) || "" : "";
    }

    function prepareImage() {
        const state = root.requestState;
        const request = ++state.id;
        root.imagePath = "";
        root.nativeWidth = 0;
        root.nativeHeight = 0;
        if (!root.enabledWallpaper || root.isSolid || !ImageCacheService.initialized)
            return;

        const path = root.wallpaper;
        const scale = CompositorService.getDisplayScale(root.screen.name);
        // Match the desktop cache (including its authored image grade), not the smaller decode.
        ImageCacheService.getLarge(path, Math.round(root.width * scale), Math.round(root.height * scale), function (cachedPath, success) {
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

    onScreenChanged: {
        root.refresh();
        Qt.callLater(root.prepareImage);
    }
    onEnabledWallpaperChanged: Qt.callLater(root.prepareImage)
    onNativeSizeModeChanged: Qt.callLater(root.prepareImage)
    onWidthChanged: Qt.callLater(root.prepareImage)
    onHeightChanged: Qt.callLater(root.prepareImage)
    onWallpaperChanged: Qt.callLater(root.prepareImage)
    Component.onCompleted: root.refresh()
    Component.onDestruction: root.requestState.alive = false

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
            if (screenName !== root.screen?.name)
                return;
            root.wallpaper = path;
            Qt.callLater(root.prepareImage);
        }
        function onWallpaperChanged(screenName, path) {
            if (screenName === root.screen?.name)
                root.wallpaper = path;
        }
    }

    Image {
        id: image
        visible: false
        source: root.enabledWallpaper && !root.isSolid ? root.imagePath : ""
        sourceSize: root.nativeSizeMode
            ? Qt.size(Math.max(1, Math.round(root.nativeWidth * root.captureSize.width / Math.max(1, root.width))),
                Math.max(1, Math.round(root.nativeHeight * root.captureSize.height / Math.max(1, root.height))))
            : root.captureSize
        fillMode: Image.Stretch
        asynchronous: true
        cache: true
    }

    Item {
        id: content
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            visible: root.ready && root.isSolid
            color: root.solidColor
        }

        ShaderEffect {
            id: mapped
            anchors.fill: parent
            visible: root.ready && !root.isSolid
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
    }

    ShaderEffectSource {
        id: mappedTexture
        sourceItem: root.provideTexture && root.ready ? content : null
        textureSize: root.captureSize
        hideSource: true
        live: root.provideTexture
        visible: false
    }
}
