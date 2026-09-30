#!/usr/bin/env bash
#
# Local-only view of Lab, active checkout, Quickshell processes, and rollback state.
set -euo pipefail

BRANCH="legacy-v4"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIVE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hydra-shell"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hydra-shell-lab"
section() { printf '\n%s\n' "$*"; }

section "Lab — $LAB_DIR"
git -C "$LAB_DIR" status -sb
printf 'HEAD: %s — %s\n' \
  "$(git -C "$LAB_DIR" rev-parse HEAD)" \
  "$(git -C "$LAB_DIR" log -1 --format=%s)"
printf 'Branch: %s\n' "$(git -C "$LAB_DIR" branch --show-current)"
if git -C "$LAB_DIR" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  printf 'Cached origin/%s (not fetched): %s\n' "$BRANCH" \
    "$(git -C "$LAB_DIR" rev-parse "refs/remotes/origin/$BRANCH")"
fi

if [[ -d "$ACTIVE_DIR/.git" ]]; then
  section "Active Hydra — $ACTIVE_DIR"
  git -C "$ACTIVE_DIR" status -sb
  printf 'HEAD: %s — %s\n' \
    "$(git -C "$ACTIVE_DIR" rev-parse HEAD)" \
    "$(git -C "$ACTIVE_DIR" log -1 --format=%s)"
  if [[ "$(git -C "$ACTIVE_DIR" branch --show-current)" == "$BRANCH" ]] &&
     [[ "$(git -C "$LAB_DIR" branch --show-current)" == "$BRANCH" ]]; then
    read -r active_only lab_only < <(git -C "$ACTIVE_DIR" rev-list --left-right --count \
      "$(git -C "$ACTIVE_DIR" rev-parse HEAD)...$(git -C "$LAB_DIR" rev-parse HEAD)")
    printf 'Lab-only commits: %s; active-only commits: %s\n' "$lab_only" "$active_only"
  fi
else
  printf '\nNo active Git checkout at %s\n' "$ACTIVE_DIR"
fi

section "Quickshell processes"
pgrep -a -x quickshell || echo "No process named quickshell."
preview_pid=
if [[ -f "$STATE_DIR/preview.pid" ]]; then
  preview_pid="$(<"$STATE_DIR/preview.pid")"
fi
if [[ "$preview_pid" =~ ^[0-9]+$ ]] && kill -0 "$preview_pid" 2>/dev/null; then
  printf 'Recorded Lab preview PID: %s\n' "$preview_pid"
else
  echo "No recorded Lab preview is running."
fi

section "Deployment state"
for key in last-known-good active-commit previous-commit deployed-at validated-at rolled-back-at; do
  if [[ -f "$STATE_DIR/$key" ]]; then
    printf '%s: %s\n' "$key" "$(<"$STATE_DIR/$key")"
  else
    printf '%s: not recorded\n' "$key"
  fi
done
[[ ! -e "$STATE_DIR/validation-pending" ]] ||
  printf 'validation-pending: %s\n' "$(<"$STATE_DIR/validation-pending")"

if command -v prowl >/dev/null 2>&1; then
  section "Prowl index"
  (cd "$LAB_DIR" && prowl status --json)
fi
if command -v bd >/dev/null 2>&1; then
  section "Beads ready work"
  (cd "$LAB_DIR" && bd ready --json)
fi
