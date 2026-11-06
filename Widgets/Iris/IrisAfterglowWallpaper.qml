// SPDX-License-Identifier: GPL-3.0-only
// Adapted from iNiR modules/iris/background/IrisAfterglowWallpaper.qml, d9ec3eae11b5c8fe51fe0ea362b1fd4d14db1b8c.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Widgets.Iris

// Afterglow's grade over whatever the desktop draws. The capture, grade and cache
// redraw only when their source changes; an unchanged frame remains one cached texture.
Item {
    id: root

    property Item source: null
    property bool live: false
    // A glass copy grades at its blur's half resolution.
    property size textureSize: Qt.size(0, 0)
    readonly property Item texture: cache
    readonly property bool ready: graded.status !== ShaderEffect.Error
    readonly property real mipLevel: Math.max(0, 3.8 - (root.textureSize.width > 0
        ? Math.log(Math.max(1, root.width) / root.textureSize.width) / Math.LN2 : 0))
    signal shown()

    // Bloom reads mip levels of this same capture, never a second wallpaper pipeline.
    ShaderEffectSource {
        id: capture
        anchors.fill: parent
        sourceItem: root.source
        hideSource: true
        live: true
        mipmap: true
        smooth: true
        visible: false
        textureSize: root.textureSize
    }
    ShaderEffect {
        id: graded
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/iris_afterglow_wallpaper.frag.qsb")
        readonly property var source: capture
        readonly property vector4d glowMix: IrisStyle.afterglowMix
        readonly property vector4d glowShadow: IrisStyle.afterglowShadow
        readonly property vector4d glowLight: IrisStyle.afterglowLight
        readonly property vector4d glowBloom: IrisStyle.afterglowBloomInk
        // xy: drawn size; z: one bloom mip-level texel in uv; w: that level.
        readonly property vector4d frame: Qt.vector4d(Math.max(1, root.width), Math.max(1, root.height),
            1.6 * 14 / Math.max(16, root.width), root.mipLevel)
        onGlowMixChanged: root.shown()
        onGlowShadowChanged: root.shown()
        onGlowLightChanged: root.shown()
        onGlowBloomChanged: root.shown()
    }
    ShaderEffectSource {
        id: cache
        anchors.fill: parent
        // A live wallpaper draws the grade itself and the cache rests.
        // Hiding the grade by visibility would instead leave an empty cache texture.
        sourceItem: graded
        hideSource: !root.live
        visible: !root.live
        live: !root.live
        textureSize: root.textureSize
    }
}
