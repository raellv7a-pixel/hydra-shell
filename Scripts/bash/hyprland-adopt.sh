#!/usr/bin/env -S bash
#
# Installs Hydra's Hyprland Lua config and registers its ScreenCast picker with
# XDPH, preserving unrelated user settings in ~/.config/hypr/xdph.conf.
# Invoked by Modules/Panels/SetupWizard/SetupHyprlandStep.qml.
#
# Usage: hyprland-adopt.sh <path-to-Assets/Hyprland>
#
# Idempotent: safe to re-run. Only touches hyprland.lua, modules/, and Hydra's
# custom_picker_binary entry in ~/.config/hypr/xdph.conf (backing up the first
# two if they exist and aren't already our own symlinks). Other settings/files
# are left exactly as they are.
#
set -euo pipefail

if [ "$#" -lt 1 ] || [ ! -d "$1" ]; then
    echo "Error: usage: $0 <path-to-Assets/Hyprland> (must be an existing directory)" >&2
    exit 1
fi

SOURCE_DIR="$(cd "$1" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
ENTRYPOINT="$HYPR_DIR/hyprland.lua"
MODULES_LINK="$HYPR_DIR/modules"
GENERATED_DIR="$HYPR_DIR/hydra-shell"
USER_LUA="$HYPR_DIR/user.lua"
BACKUP_DIR="$HYPR_DIR/hydra-shell-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$HYPR_DIR"

# XDPH reads this setting from ~/.config/hypr/xdph.conf. The helper changes
# only the custom picker key and restarts XDPH when that file actually changes.
"$SCRIPT_DIR/xdph-adopt.sh" "$SCRIPT_DIR/corvus-share-picker.sh"

backed_up=false
backup_if_real() {
    # Back up $1 unless it is missing or is already our own symlink into
    # SOURCE_DIR (re-running this script must never "back up" our own link).
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$SOURCE_DIR/$(basename "$target")" 2>/dev/null || echo __none__)" ]; then
            return 0
        fi
        mkdir -p "$BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/$(basename "$target")"
        backed_up=true
    fi
}

backup_if_real "$ENTRYPOINT"
backup_if_real "$MODULES_LINK"

ln -sf "$SOURCE_DIR/hyprland.lua" "$ENTRYPOINT"
ln -sfn "$SOURCE_DIR/modules" "$MODULES_LINK"

mkdir -p "$GENERATED_DIR"

if [ ! -e "$USER_LUA" ]; then
    cp "$SOURCE_DIR/user.lua.example" "$USER_LUA"
fi

if [ "$backed_up" = true ]; then
    echo "BACKUP_DIR:$BACKUP_DIR"
fi

if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi

echo "RESULT:OK"
