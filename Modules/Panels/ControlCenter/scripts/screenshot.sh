#!/usr/bin/env bash
set -euo pipefail

mode="${1:-region}"
screen="${2:-}"

copy_fullscreen() {
  if [ -n "$screen" ]; then
    grim -o "$screen" - | wl-copy --type image/png
  else
    grim - | wl-copy --type image/png
  fi
}

copy_region() {
  local region
  region="$(slurp)" || return 1
  grim -g "$region" - | wl-copy --type image/png
}


if [ "$mode" = "active-screen" ] || [ "$mode" = "screen" ] || [ "$mode" = "fullscreen" ]; then
  copy_fullscreen
else
  copy_region
fi
