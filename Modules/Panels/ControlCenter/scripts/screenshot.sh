#!/usr/bin/env bash
set -u

mode="${1:-region}"

copy_fullscreen() {
  grim - | wl-copy --type image/png
}

copy_region() {
  local region
  region="$(slurp)" || return 1
  grim -g "$region" - | wl-copy --type image/png
}

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprshot >/dev/null 2>&1; then
  if [ "$mode" = "active-screen" ] || [ "$mode" = "screen" ] || [ "$mode" = "fullscreen" ]; then
    exec hyprshot -m output -m active --clipboard-only --silent
  fi

  exec hyprshot --freeze --clipboard-only --mode region --silent
fi

if [ -n "${NIRI_SOCKET:-}" ] && command -v niri >/dev/null 2>&1; then
  exec niri msg action screenshot
fi

if [ "$mode" = "active-screen" ] || [ "$mode" = "screen" ] || [ "$mode" = "fullscreen" ]; then
  copy_fullscreen
else
  copy_region
fi
