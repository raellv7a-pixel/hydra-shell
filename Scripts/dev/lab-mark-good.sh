#!/usr/bin/env bash
# Record a user-validated active Hydra commit as last-known-good.
set -euo pipefail
ACTIVE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hydra-shell"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hydra-shell-lab"

usage() { echo "Usage: $0 <full-commit> --visual-confirmed"; }
(($# == 2)) || { usage >&2; exit 2; }
commit="$1"
[[ "$2" == "--visual-confirmed" ]] || { usage >&2; exit 2; }
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { usage >&2; exit 2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ ! -L "$ACTIVE_DIR" ]] || die "Active path is a symlink."
[[ -d "$ACTIVE_DIR/.git" ]] || die "No active Git installation at $ACTIVE_DIR."
[[ "$(git -C "$ACTIVE_DIR" branch --show-current)" == "legacy-v4" ]] || die "Active checkout is not on legacy-v4."
[[ -z "$(git -C "$ACTIVE_DIR" status --porcelain)" ]] || die "Active checkout is dirty."
[[ "$(git -C "$ACTIVE_DIR" rev-parse HEAD)" == "$commit" ]] || die "Active HEAD does not match the supplied commit."
mapfile -t quickshell_pids < <({ pgrep -x qs || true; pgrep -x quickshell || true; } | sort -un)
active_pids=()
for pid in "${quickshell_pids[@]}"; do
  args="$(ps -o args= -p "$pid" 2>/dev/null || true)"
  [[ "$args" =~ (^|[[:space:]])(-c|--config)[[:space:]]+hydra-shell($|[[:space:]]) ]] &&
    active_pids+=("$pid")
done
((${#active_pids[@]} == 1)) || die "Expected exactly one active qs -c hydra-shell process; found ${#active_pids[@]}."
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
git -C "$ACTIVE_DIR" update-ref refs/hydra-shell/last-known-good "$commit"
printf '%s\n' "$commit" >"$STATE_DIR/.last-known-good.$$"
chmod 600 "$STATE_DIR/.last-known-good.$$"
mv -f -- "$STATE_DIR/.last-known-good.$$" "$STATE_DIR/last-known-good"
printf '%s\n' "$commit" >"$STATE_DIR/.active-commit.$$"
chmod 600 "$STATE_DIR/.active-commit.$$"
mv -f -- "$STATE_DIR/.active-commit.$$" "$STATE_DIR/active-commit"
printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$STATE_DIR/.validated-at.$$"
chmod 600 "$STATE_DIR/.validated-at.$$"
mv -f -- "$STATE_DIR/.validated-at.$$" "$STATE_DIR/validated-at"
rm -f -- "$STATE_DIR/validation-pending"
echo "Recorded $commit as last-known-good after explicit visual confirmation."
