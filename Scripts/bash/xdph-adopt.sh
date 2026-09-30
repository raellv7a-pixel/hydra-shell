#!/usr/bin/env bash
# Ensure XDPH uses Hydra's ScreenCast picker without replacing other settings.
set -euo pipefail

if [[ $# -lt 1 || ! -x $1 ]]; then
  echo "Error: usage: $0 <executable-corvus-share-picker.sh>" >&2
  exit 1
fi

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
config_file="$config_dir/xdph.conf"
picker="$(readlink -f "$1")"
mkdir -p "$config_dir"
tmp_file="$(mktemp "$config_dir/.xdph.conf.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

awk -v picker="$picker" '
function braces(line, copy, opens, closes) {
  copy = line
  opens = gsub(/\{/, "{", copy)
  closes = gsub(/\}/, "}", line)
  return opens - closes
}
function write_picker() {
  print "    custom_picker_binary = " picker
  picker_written = 1
}
BEGIN { in_screencopy = 0; found_screencopy = 0; picker_written = 0; depth = 0 }
{
  if (!in_screencopy && $0 ~ /^[[:space:]]*screencopy[[:space:]]*\{/) {
    in_screencopy = 1
    found_screencopy = 1
    depth = braces($0)
    print
    next
  }
  if (in_screencopy) {
    if ($0 ~ /^[[:space:]]*custom_picker_binary[[:space:]]*=/) {
      if (!picker_written) write_picker()
    } else {
      if (depth + braces($0) == 0 && !picker_written) write_picker()
      print
    }
    depth += braces($0)
    if (depth == 0) in_screencopy = 0
    next
  }
  print
}
END {
  if (!found_screencopy) {
    if (NR > 0) print ""
    print "screencopy {"
    write_picker()
    print "}"
  }
}' "$config_file" 2>/dev/null >"$tmp_file" || {
  # A missing input file is expected on first adoption.
  if [[ -e $config_file ]]; then
    echo "Error: could not read $config_file" >&2
    exit 1
  fi
  printf 'screencopy {\n    custom_picker_binary = %s\n}\n' "$picker" >"$tmp_file"
}

if [[ -e $config_file ]] && cmp -s "$config_file" "$tmp_file"; then
  echo "XDPH picker already configured: $config_file"
  exit 0
fi

if [[ -e $config_file ]]; then
  chmod --reference="$config_file" "$tmp_file"
fi
mv "$tmp_file" "$config_file"
echo "Configured XDPH Hydra picker: $config_file"

# XDPH reads xdph.conf at startup; restart only the active user service.
if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet xdg-desktop-portal-hyprland.service; then
  systemctl --user restart xdg-desktop-portal-hyprland.service
fi
