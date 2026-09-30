#!/usr/bin/env bash
# Restore active Hydra to the explicitly recorded last-known-good Git commit.
set -euo pipefail
ACTIVE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hydra-shell"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hydra-shell-lab"
LKG_FILE="$STATE_DIR/last-known-good"
ACTIVE_FILE="$STATE_DIR/active-commit"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ ! -L "$ACTIVE_DIR" ]] || die "Active path is a symlink."
[[ -d "$ACTIVE_DIR/.git" ]] || die "No active Git installation at $ACTIVE_DIR."
[[ -f "$LKG_FILE" && -f "$ACTIVE_FILE" ]] || die "No deploy state is recorded."
[[ -z "$(git -C "$ACTIVE_DIR" status --porcelain)" ]] ||
  die "Active checkout is dirty; refusing to discard local work."
current="$(git -C "$ACTIVE_DIR" rev-parse HEAD)"
deployed="$(<"$ACTIVE_FILE")"
last_good="$(<"$LKG_FILE")"
[[ "$current" == "$deployed" ]] ||
  die "Active HEAD ($current) differs from recorded deploy ($deployed); inspect manually."
git -C "$ACTIVE_DIR" cat-file -e "$last_good^{commit}" 2>/dev/null ||
  die "Last-known-good commit $last_good is missing locally; rollback is offline but object is unavailable."
[[ "$current" != "$last_good" ]] || { echo "Active Hydra is already last-known-good ($last_good)."; exit 0; }
[[ "$(git -C "$ACTIVE_DIR" branch --show-current)" == "legacy-v4" ]] ||
  die "Active checkout is not on legacy-v4."

command -v qs >/dev/null 2>&1 || die "qs is required to reload the restored checkout."
mapfile -t quickshell_pids < <({ pgrep -x qs || true; pgrep -x quickshell || true; } | sort -un)
active_pids=()
for pid in "${quickshell_pids[@]}"; do
  args="$(ps -o args= -p "$pid" 2>/dev/null || true)"
  [[ "$args" =~ (^|[[:space:]])(-c|--config)[[:space:]]+hydra-shell($|[[:space:]]) ]] &&
    active_pids+=("$pid")
done
((${#active_pids[@]} == 1)) || die "Expected exactly one active qs -c hydra-shell process."
active_pid="${active_pids[0]}"

git -C "$ACTIVE_DIR" update-ref refs/hydra-shell/failed-deploy "$current"
git -C "$ACTIVE_DIR" reset --hard "$last_good"
sleep 2
kill -0 "$active_pid" 2>/dev/null ||
  die "Active Hydra PID $active_pid exited after rollback; files are restored but runtime validation failed."
printf '%s\n' "$last_good" >"$STATE_DIR/.active-commit.$$"
chmod 600 "$STATE_DIR/.active-commit.$$"
mv -f -- "$STATE_DIR/.active-commit.$$" "$ACTIVE_FILE"
printf '%s\n' "$current" >"$STATE_DIR/.previous-commit.$$"
chmod 600 "$STATE_DIR/.previous-commit.$$"
mv -f -- "$STATE_DIR/.previous-commit.$$" "$STATE_DIR/previous-commit"
printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$STATE_DIR/.rolled-back-at.$$"
chmod 600 "$STATE_DIR/.rolled-back-at.$$"
mv -f -- "$STATE_DIR/.rolled-back-at.$$" "$STATE_DIR/rolled-back-at"
rm -f -- "$STATE_DIR/validation-pending"
echo "Rolled active Hydra back to $last_good. Quickshell file watching should reload it; verify the running shell and logs."
