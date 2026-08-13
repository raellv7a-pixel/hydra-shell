#!/usr/bin/env bash
# Grants the invoking user passwordless sudo for the papirus-folders binary,
# so the "Papirus Folders" theming template (Services/Theming/TemplateRegistry.qml,
# id "papirusFolders") can recolor icon folders in the background on every
# palette change without a password prompt.
#
# papirus-folders needs to write into /usr/share/icons/Papirus (root:root,
# 755) — there is no unprivileged path. The template's post_hook runs
# `sudo -n papirus-folders -C <color> -u`, fire-and-forget with stderr
# discarded; without a NOPASSWD rule that `sudo -n` fails silently every
# time and the "just enable the toggle" UX never happens.
#
# This script MUST run as root (invoked via pkexec/polkit-elevate.sh — see
# Services/System/PapirusFoldersSetupService.qml) and takes the target user
# and the resolved papirus-folders path as arguments, since only the
# unprivileged caller can resolve $USER/$PATH correctly.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "error: must run as root (use polkit-elevate.sh)" >&2
  exit 1
fi

if [[ $# -ne 2 ]]; then
  echo "usage: ${0##*/} <username> <papirus-folders-absolute-path>" >&2
  exit 2
fi

target_user="$1"
binary_path="$2"

if ! id -u -- "$target_user" >/dev/null 2>&1; then
  echo "error: no such user: $target_user" >&2
  exit 1
fi

if [[ "$binary_path" != /* ]] || [[ ! -x "$binary_path" ]]; then
  echo "error: not an executable absolute path: $binary_path" >&2
  exit 1
fi

sudoers_dir="/etc/sudoers.d"
drop_in="$sudoers_dir/hydra-shell-papirus-folders"
rule="$target_user ALL=(root) NOPASSWD: $binary_path"

# Already installed with the exact rule we'd write — nothing to do. Keeps
# re-toggling the setting in Settings from re-prompting for a password.
if [[ -f "$drop_in" ]] && [[ "$(cat -- "$drop_in")" == "$rule" ]]; then
  exit 0
fi

tmp="$(mktemp "$sudoers_dir/.hydra-shell-papirus-folders.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$rule" > "$tmp"
chmod 0440 "$tmp"

# Never install a sudoers fragment that hasn't been syntax-checked — a
# malformed /etc/sudoers.d file can break sudo for the entire system.
if ! visudo -cf "$tmp" >/dev/null 2>&1; then
  echo "error: generated sudoers rule failed validation, aborting" >&2
  exit 1
fi

mv -f "$tmp" "$drop_in"
trap - EXIT
chown root:root "$drop_in"
chmod 0440 "$drop_in"
