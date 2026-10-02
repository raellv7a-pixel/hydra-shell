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


if [ "$mode" = "active-screen" ] || [ "$mode" = "screen" ] || [ "$mode" = "fullscreen" ]; then
  copy_fullscreen
else
  copy_region
fi
