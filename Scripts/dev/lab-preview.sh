#!/usr/bin/env bash
#
# Run a separate foreground Quickshell instance from this Lab checkout.
# It never signals or replaces the active Hydra process.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hydra-shell-lab"
PREVIEW_PID_FILE="$STATE_DIR/preview.pid"

command -v qs >/dev/null 2>&1 || {
  echo "qs (Hydra-compatible Quickshell) is not installed or not on PATH." >&2
  exit 1
}
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
if [[ -f "$PREVIEW_PID_FILE" ]]; then
  old_pid="$(<"$PREVIEW_PID_FILE")"
  if [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "A Lab preview is already recorded as PID $old_pid." >&2
    exit 1
  fi
  rm -f -- "$PREVIEW_PID_FILE"
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$STATE_DIR/preview-$timestamp-$$.log"
qs_pid=
log_pid=
cleanup() {
  [[ -z "$log_pid" ]] || kill "$log_pid" 2>/dev/null || true
  if [[ -n "$qs_pid" ]] && kill -0 "$qs_pid" 2>/dev/null; then
    kill -TERM "$qs_pid" 2>/dev/null || true
    wait "$qs_pid" 2>/dev/null || true
  fi
  if [[ -f "$PREVIEW_PID_FILE" ]] && [[ "$(<"$PREVIEW_PID_FILE")" == "$qs_pid" ]]; then
    rm -f -- "$PREVIEW_PID_FILE"
  fi
}
on_signal() {
  [[ -z "$qs_pid" ]] || kill -TERM "$qs_pid" 2>/dev/null || true
  exit 130
}
trap cleanup EXIT
trap on_signal INT TERM HUP

printf 'Lab preview: %s\nCommit: %s\nLog: %s\n' \
  "$LAB_DIR" "$(git -C "$LAB_DIR" rev-parse HEAD)" "$log_file"
echo "Active Hydra is not touched. Ctrl+C terminates only this preview process."
qs -p "$LAB_DIR" "$@" >>"$log_file" 2>&1 &
qs_pid=$!
printf '%s\n' "$qs_pid" >"$PREVIEW_PID_FILE"
chmod 600 "$PREVIEW_PID_FILE"
tail -n 0 -F "$log_file" &
log_pid=$!
set +e
wait "$qs_pid"
status=$?
set -e
exit "$status"
