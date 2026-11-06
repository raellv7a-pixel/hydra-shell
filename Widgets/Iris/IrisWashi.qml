// Adapted from iNiR modules/iris/style/IrisWashi.qml (GPL-3.0),
// d9ec3eae11b5c8fe51fe0ea362b1fd4d14db1b8c. Original solver and settle/cache lifecycle.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../../Helpers/MaterialProfiles.js" as MaterialProfiles

Singleton {
    id: root

    readonly property int version: 23
    readonly property string cachePath: Settings.cacheDir + "iris-washi.json"
    readonly property var profile: MaterialProfiles.resolve(Settings.data.ui.visualVariant)
    readonly property bool enabled: root.profile.iris

    function hex(c: color): string {
        const part = v => ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2)
        return "#" + part(c.r) + part(c.g) + part(c.b)
    }
    // Only unadapted Hydra palette seeds are read here. Reading mPrimary after
    // HydraColor publishes this solve would feed the result back into its input.
    readonly property string requestJson: JSON.stringify({
        language: root.profile.language,
        variant: "tonalSpot",
        material: root.profile.surface,
        glass: root.profile.glass,
        inkStyle: "washi",
        darkStyle: "style",
        accent: root.profile.accent,
        accentHue: root.profile.accentHue,
        highlight: root.profile.highlight,
        highlightHue: root.profile.highlightHue,
        vibrance: 0.85,
        tune: {
            dark: { tone: 0, colour: 100, widgets: 100, warmth: 20 },
            ink: { tone: 0, colour: 100, widgets: 100, warmth: 50 },
            light: { tone: -8, colour: 85, widgets: 110, warmth: 38 }
        },
        seeds: {
            wallpaper: root.hex(IrisMood.seed),
            primary: root.hex(HydraColor.sourcePrimary),
            secondary: root.hex(HydraColor.sourceSecondary),
            tertiary: root.hex(HydraColor.sourceTertiary),
            background: root.hex(HydraColor.sourceSurface)
        }
    })
    function parse(text: string): var {
        try {
            const out = JSON.parse(text)
            return out?.schemes?.dark && out?.schemes?.ink && out?.schemes?.light ? out : null
        } catch (e) { return null }
    }
    property var data: root.parse(root.cache.text()) ?? root.parse(root.fallback.text())
    function palette(scheme: string): var {
        return root.data?.schemes?.[scheme] ?? root.data?.schemes?.dark ?? ({})
    }

    property bool again: false
    property bool warned: false
    function run(): void {
        if (!root.enabled || !Settings.directoriesCreated) return
        if (root.data?.request === root.requestJson && root.data?.version === root.version) return
        if (solver.running) { root.again = true; return }
        solver.command = ["bash", Quickshell.shellPath("Scripts/materials/washi.sh"), "--request", root.requestJson, "--out", root.cachePath]
        solver.running = true
    }
    readonly property Timer settle: Timer { interval: 60; onTriggered: root.run() }
    onRequestJsonChanged: root.settle.restart()
    onEnabledChanged: root.settle.restart()
    Component.onCompleted: root.settle.restart()
    Connections {
        target: Settings
        function onDirectoriesCreatedChanged() { root.settle.restart() }
    }
    readonly property FileView cache: FileView { path: root.cachePath; blockLoading: true; printErrors: false }
    readonly property FileView fallback: FileView { path: Quickshell.shellPath("Assets/Iris/iris-washi.json"); blockLoading: true }
    readonly property Process solver: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const out = root.parse(this.text)
                if (out) root.data = out
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0 && !root.warned) {
                root.warned = true
                console.warn("[IrisWashi]", this.text.trim())
            }
        }
        onExited: if (root.again) { root.again = false; root.settle.restart() }
    }
}
