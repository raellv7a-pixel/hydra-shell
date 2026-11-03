pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

Singleton {
  id: root

  // Icon artwork only: iRiS identity colors, not Hydra interface surface tokens.
  // Provenance and font derivation: Assets/Fonts/material-symbols/ATTRIBUTION.txt.
  readonly property QtObject identity: QtObject {
    readonly property color blue: "#0a84ff"
    readonly property color sky: "#64d2ff"
    readonly property color teal: "#30b0c7"
    readonly property color green: "#34c759"
    readonly property color yellow: "#e0a800"
    readonly property color orange: "#ff9f0a"
    readonly property color red: "#ff453a"
    readonly property color pink: "#ff375f"
    readonly property color indigo: "#5e5ce6"
    readonly property color purple: "#bf5af2"
    readonly property color lavender: "#b4a0ff"
    readonly property color gray: "#8e8e93"
  }
  readonly property color glyphColor: "#ffffff"
  readonly property real glyphShare: 0.64
  readonly property real cornerRatio: 0.26
  readonly property real gradientLift: 1.18
  readonly property bool fontReady: materialFont.status === FontLoader.Ready
  readonly property string fontFamily: materialFont.name

  FontLoader {
    id: materialFont
    source: Qt.resolvedUrl("../Assets/Fonts/material-symbols/HydraMaterialSymbolsRounded-Filled.ttf")
    onStatusChanged: {
      if (status === FontLoader.Error) {
        Logger.e("ColoredIcons", "Failed to load bundled Material Symbols font:", source, "Using Tabler artwork instead.");
      }
    }
  }

  // Glyphs name the bundled, fully filled Material Symbols Rounded repertoire.
  // A fallback is needed only when a semantic key is not also a Tabler icon key.
  readonly property var icons: ({
                                  "settings-general": {
                                    glyph: "settings",
                                    tint: "gray"
                                  },
                                  "settings-user-interface": {
                                    glyph: "style",
                                    tint: "purple"
                                  },
                                  "settings-color-scheme": {
                                    glyph: "palette",
                                    tint: "pink"
                                  },
                                  "settings-wallpaper": {
                                    glyph: "wallpaper",
                                    tint: "teal"
                                  },
                                  "settings-bar": {
                                    glyph: "pill",
                                    tint: "blue"
                                  },
                                  "settings-dock": {
                                    glyph: "dock_to_bottom",
                                    tint: "indigo"
                                  },
                                  "clock": {
                                    glyph: "schedule",
                                    tint: "orange"
                                  },
                                  "settings-control-center": {
                                    glyph: "toggle_on",
                                    tint: "gray"
                                  },
                                  "settings-launcher": {
                                    glyph: "search",
                                    tint: "blue"
                                  },
                                  "settings-notifications": {
                                    glyph: "notifications",
                                    tint: "red"
                                  },
                                  "settings-osd": {
                                    glyph: "volume_up",
                                    tint: "pink"
                                  },
                                  "settings-session-menu": {
                                    glyph: "power_settings_new",
                                    tint: "red"
                                  },
                                  "shield-lock": {
                                    glyph: "shield_lock",
                                    tint: "gray"
                                  },
                                  "settings-lock-screen": {
                                    glyph: "lock",
                                    tint: "gray"
                                  },
                                  "settings-idle": {
                                    glyph: "bedtime",
                                    tint: "indigo"
                                  },
                                  "settings-audio": {
                                    glyph: "volume_up",
                                    tint: "pink"
                                  },
                                  "settings-display": {
                                    glyph: "brightness_6",
                                    tint: "blue"
                                  },
                                  "settings-network": {
                                    glyph: "wifi",
                                    tint: "blue"
                                  },
                                  "settings-location": {
                                    glyph: "location_on",
                                    tint: "teal"
                                  },
                                  "settings-system-monitor": {
                                    glyph: "monitoring",
                                    tint: "green"
                                  },
                                  "app-window": {
                                    glyph: "select_window",
                                    tint: "orange"
                                  },
                                  "plugin": {
                                    glyph: "extension",
                                    tint: "purple"
                                  },
                                  "settings-hooks": {
                                    glyph: "code",
                                    tint: "gray"
                                  },
                                  "settings-about": {
                                    glyph: "info",
                                    tint: "lavender"
                                  },
                                  "settings": {
                                    glyph: "settings",
                                    tint: "gray"
                                  },
                                  "settings-2": {
                                    glyph: "tune",
                                    tint: "gray"
                                  },
                                  "settings-automation": {
                                    glyph: "settings_suggest",
                                    tint: "indigo"
                                  },
                                  "keyboard": {
                                    glyph: "keyboard",
                                    tint: "gray"
                                  },
                                  "info": {
                                    glyph: "info",
                                    tint: "lavender"
                                  },
                                  "users": {
                                    glyph: "group",
                                    tint: "blue"
                                  },
                                  "user": {
                                    glyph: "person",
                                    tint: "blue"
                                  },
                                  "heart": {
                                    glyph: "favorite",
                                    tint: "pink"
                                  },
                                  "volume": {
                                    glyph: "volume_up",
                                    tint: "pink"
                                  },
                                  "devices": {
                                    glyph: "devices",
                                    tint: "blue"
                                  },
                                  "music": {
                                    glyph: "music_note",
                                    tint: "pink"
                                  },
                                  "activity": {
                                    glyph: "monitoring",
                                    tint: "orange"
                                  },
                                  "palette": {
                                    glyph: "palette",
                                    tint: "pink"
                                  },
                                  "grid-dots": {
                                    glyph: "apps",
                                    tint: "yellow"
                                  },
                                  "device-desktop": {
                                    glyph: "desktop_windows",
                                    tint: "blue"
                                  },
                                  "layout-sidebar-right": {
                                    glyph: "dock_to_right",
                                    tint: "green"
                                  },
                                  "file-code": {
                                    glyph: "code",
                                    tint: "gray"
                                  },
                                  "wifi": {
                                    glyph: "wifi",
                                    tint: "blue"
                                  },
                                  "bluetooth": {
                                    glyph: "bluetooth",
                                    tint: "blue"
                                  },
                                  "layout-dashboard": {
                                    glyph: "space_dashboard",
                                    tint: "green"
                                  },
                                  "sparkles": {
                                    glyph: "auto_awesome",
                                    tint: "purple"
                                  },
                                  "sun": {
                                    glyph: "light_mode",
                                    tint: "yellow"
                                  },
                                  "moon-stars": {
                                    glyph: "dark_mode",
                                    tint: "indigo"
                                  },
                                  "list": {
                                    glyph: "view_list",
                                    tint: "blue"
                                  },
                                  "photo": {
                                    glyph: "wallpaper",
                                    tint: "teal"
                                  },
                                  "image": {
                                    glyph: "image",
                                    tint: "teal"
                                  },
                                  "folder": {
                                    glyph: "folder",
                                    tint: "blue"
                                  },
                                  "clipboard": {
                                    glyph: "content_paste",
                                    tint: "teal"
                                  },
                                  "terminal": {
                                    glyph: "terminal",
                                    tint: "gray"
                                  },
                                  "history": {
                                    glyph: "history",
                                    tint: "orange"
                                  },
                                  "bell": {
                                    glyph: "notifications",
                                    tint: "red"
                                  },
                                  "list-check": {
                                    glyph: "checklist",
                                    tint: "green"
                                  },
                                  "download": {
                                    glyph: "download",
                                    tint: "green"
                                  },
                                  "world": {
                                    glyph: "language",
                                    tint: "teal"
                                  },
                                  "map-pin": {
                                    glyph: "location_on",
                                    tint: "teal"
                                  },
                                  "calendar": {
                                    glyph: "calendar_month",
                                    tint: "red"
                                  },
                                  "bolt": {
                                    glyph: "bolt",
                                    tint: "yellow"
                                  },
                                  "alarm": {
                                    glyph: "alarm",
                                    tint: "orange"
                                  },
                                  "chart-bar": {
                                    glyph: "bar_chart",
                                    tint: "green"
                                  },
                                  "focus-2": {
                                    glyph: "center_focus_strong",
                                    tint: "green"
                                  },
                                  "screen-share": {
                                    glyph: "screen_share",
                                    tint: "blue"
                                  },
                                  "folder-tools": {
                                    glyph: "build",
                                    tint: "red",
                                    fallback: "tools"
                                  },
                                  "folder-productivity": {
                                    glyph: "work",
                                    tint: "blue",
                                    fallback: "briefcase"
                                  },
                                  "folder-creativity": {
                                    glyph: "palette",
                                    tint: "pink",
                                    fallback: "palette"
                                  },
                                  "folder-games": {
                                    glyph: "sports_esports",
                                    tint: "purple",
                                    fallback: "device-gamepad-2"
                                  },
                                  "folder-development": {
                                    glyph: "code",
                                    tint: "gray",
                                    fallback: "code"
                                  },
                                  "folder-multimedia": {
                                    glyph: "play_circle",
                                    tint: "pink",
                                    fallback: "player-play"
                                  },
                                  "folder-internet": {
                                    glyph: "language",
                                    tint: "teal",
                                    fallback: "world"
                                  },
                                  "folder-system": {
                                    glyph: "settings",
                                    tint: "gray",
                                    fallback: "settings"
                                  },
                                  "folder-education": {
                                    glyph: "school",
                                    tint: "orange",
                                    fallback: "school"
                                  },
                                  "folder-utilities": {
                                    glyph: "construction",
                                    tint: "orange",
                                    fallback: "tools"
                                  }
                                })

  function get(iconName) {
    return root.icons[iconName] ?? null;
  }
}
