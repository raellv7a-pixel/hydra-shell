// SPDX-License-Identifier: GPL-3.0-only
// Adapted from iNiR modules/iris/field/IrisGlassSource.qml, d9ec3eae11b5c8fe51fe0ea362b1fd4d14db1b8c.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Widgets.Iris

Item {
    id: root

    property var screen: null
    property bool live: true
    width: root.screen?.width ?? 0
    height: root.screen?.height ?? 0
    readonly property bool ready: view.ready && (!grade.active || (grade.status === Loader.Ready && grade.item.ready))
    readonly property Item texture: blurred

    // Hidden by opacity, not visibility: the source must still render into its texture.
    opacity: 0

    readonly property size half: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))

    IrisWallpaperView {
        id: view
        anchors.fill: parent
        screen: root.screen
        live: root.live
        // Under a grade the grade captures the view itself, avoiding a parallel capture.
        provideTexture: !grade.active
        decodeSize: Qt.size(Math.max(1, Math.round((root.screen?.width ?? root.width) / 2)),
            Math.max(1, Math.round((root.screen?.height ?? root.height) / 2)))
    }

    // Grade before blur, at the blur's half resolution: glass carries the same
    // Afterglow light as the wallpaper, without developing a separate picture.
    Loader {
        id: grade
        anchors.fill: parent
        active: IrisStyle.afterglowWallpaper
        sourceComponent: afterglowGrade
    }
    Component {
        id: afterglowGrade
        IrisAfterglowWallpaper {
            source: view
            textureSize: root.half
        }
    }

    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.textureSize: root.half
        source: root.ready ? (grade.active ? grade.item.texture : view.textureItem) : null
        autoPaddingEnabled: false
        blurEnabled: true
        blur: IrisStyle.glassBlurAmount
        blurMax: IrisStyle.glassBlurMax
        // Hydra's desktop image grade is already included in ImageCacheService's output.
        saturation: Math.max(-1, Math.min(1, IrisStyle.glassSaturation))
        contrast: 0
    }
}
