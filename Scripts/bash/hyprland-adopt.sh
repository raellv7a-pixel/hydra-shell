#!/usr/bin/env -S bash
#
# Installs hydra-shell's own Hyprland Lua config as the user's
# ~/.config/hypr/hyprland.lua, per PLANO_INTEGRACAO_HYPRMOD.md §4.
# Invoked by Modules/Panels/SetupWizard/SetupHyprlandStep.qml.
#
# Usage: hyprland-adopt.sh <path-to-Assets/Hyprland>
#
# Idempotent: safe to re-run. Only touches hyprland.lua and modules/ (backed
# up first if they exist and aren't already our own symlinks) — everything
# else already in ~/.config/hypr (hyprlock.conf, hypridle.conf, hyprpaper.conf,
# monitors.lua, user's own colors.lua, ...) is left exactly as it is.
set -euo pipefail

if [ "$#" -lt 1 ] || [ ! -d "$1" ]; then
    echo "Error: usage: $0 <path-to-Assets/Hyprland> (must be an existing directory)" >&2
    exit 1
fi

SOURCE_DIR="$(cd "$1" && pwd)"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
ENTRYPOINT="$HYPR_DIR/hyprland.lua"
MODULES_LINK="$HYPR_DIR/modules"
GENERATED_DIR="$HYPR_DIR/hydra-shell"
USER_LUA="$HYPR_DIR/user.lua"
BACKUP_DIR="$HYPR_DIR/hydra-shell-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$HYPR_DIR"

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
