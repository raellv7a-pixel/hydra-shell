#!/usr/bin/env bash
#
# Validate and fast-forward the active Hydra from a clean, previewed Lab commit.
# Never pushes to or fetches from the network remote.
set -euo pipefail

BRANCH="legacy-v4"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIVE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hydra-shell"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hydra-shell-lab"
LKG_FILE="$STATE_DIR/last-known-good"
PREVIEWED=
YES=false

usage() {
  echo "Usage: $0 --preview-validated <full-commit> [--yes]"
}
while (($#)); do
  case "$1" in
    --preview-validated)
      (($# >= 2)) || { usage >&2; exit 2; }
      PREVIEWED="$2"
      shift 2
      ;;
    -y|--yes) YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '\n==> %s\n' "$*"; }
write_state() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp "$STATE_DIR/.${key}.XXXXXX")"
  printf '%s\n' "$value" >"$tmp"
  chmod 600 "$tmp"
  mv -f -- "$tmp" "$STATE_DIR/$key"
}

[[ "$PREVIEWED" =~ ^[0-9a-f]{40}$ ]] ||
  die "Supply the full commit hash explicitly validated in lab-preview.sh."
[[ ! -L "$ACTIVE_DIR" ]] || die "Active path is a symlink; refusing to deploy."
[[ -d "$ACTIVE_DIR/.git" ]] || die "No active Git installation at $ACTIVE_DIR."
[[ -d "$LAB_DIR/.git" ]] || die "Lab checkout has no Git metadata."
[[ "$(git -C "$LAB_DIR" branch --show-current)" == "$BRANCH" ]] ||
  die "Lab must be on $BRANCH."
[[ -z "$(git -C "$LAB_DIR" status --porcelain)" ]] ||
  die "Lab is dirty; commit or safely stash all changes before deploying."
candidate="$(git -C "$LAB_DIR" rev-parse HEAD)"
[[ "$candidate" == "$PREVIEWED" ]] ||
  die "Preview confirmation is for $PREVIEWED, but Lab HEAD is $candidate."
[[ "$(git -C "$ACTIVE_DIR" branch --show-current)" == "$BRANCH" ]] ||
  die "Active checkout must be on $BRANCH."
[[ -z "$(git -C "$ACTIVE_DIR" status --porcelain)" ]] ||
  die "Active checkout is dirty; no files were changed."
lab_remote="$(git -C "$LAB_DIR" remote get-url origin)"
active_remote="$(git -C "$ACTIVE_DIR" remote get-url origin)"
[[ "$lab_remote" == "$active_remote" ]] ||
  die "Lab and active origin URLs differ; refusing to cross repositories."
[[ -f "$LKG_FILE" ]] ||
  die "No last-known-good recorded. Validate the active baseline, then run lab-mark-good.sh."
last_good="$(<"$LKG_FILE")"
active_head="$(git -C "$ACTIVE_DIR" rev-parse HEAD)"
[[ "$active_head" == "$last_good" ]] ||
  die "Active HEAD ($active_head) is not recorded last-known-good ($last_good); inspect/rollback first."
[[ "$(git -C "$LAB_DIR" cat-file -t "$candidate" 2>/dev/null)" == commit ]] ||
  die "Lab candidate is not a commit."
git -C "$LAB_DIR" merge-base --is-ancestor "$last_good" "$candidate" ||
  die "Candidate is not a fast-forward from last-known-good."
command -v qs >/dev/null 2>&1 || die "qs is required to validate/reload the active shell."
command -v prowl >/dev/null 2>&1 || die "prowl is required for the project doctor check."

mapfile -t quickshell_pids < <({ pgrep -x qs || true; pgrep -x quickshell || true; } | sort -un)
active_pids=()
for pid in "${quickshell_pids[@]}"; do
  args="$(ps -o args= -p "$pid" 2>/dev/null || true)"
  [[ "$args" =~ (^|[[:space:]])(-c|--config)[[:space:]]+hydra-shell($|[[:space:]]) ]] &&
    active_pids+=("$pid")
done
((${#active_pids[@]} == 1)) || die "Expected exactly one active qs -c hydra-shell process; found ${#active_pids[@]}."
active_pid="${active_pids[0]}"

mapfile -t changed_qml < <(git -C "$LAB_DIR" diff --name-only "$last_good..$candidate" -- '*.qml')
if ((${#changed_qml[@]})); then
  log "Checking changed QML with pinned Qt formatter/parser"
  (cd "$LAB_DIR" && ./Scripts/dev/qmlfmt.sh --check "${changed_qml[@]}")
  qml_lint="${HYDRA_QT_TOOLS_DIR:-$HOME/.cache/hydra-shell-tools/qt}/6.10.3/gcc_64/bin/qmllint"
  [[ -x "$qml_lint" ]] || qml_lint="$(command -v qmllint || true)"
  [[ -n "$qml_lint" ]] || die "Changed QML requires qmllint; install the pinned Qt tools."
  (cd "$LAB_DIR" && "$qml_lint" -I "$LAB_DIR" "${changed_qml[@]}")
fi

log "Running Prowl structural doctor"
(cd "$LAB_DIR" && prowl doctor --fail-on error)
log "Recording rollback boundary and advancing active checkout locally"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
git -C "$ACTIVE_DIR" update-ref refs/hydra-shell/last-known-good "$last_good"
git -C "$ACTIVE_DIR" fetch --no-tags "$LAB_DIR" "$BRANCH"
git -C "$ACTIVE_DIR" merge --ff-only FETCH_HEAD
deployed="$(git -C "$ACTIVE_DIR" rev-parse HEAD)"
[[ "$deployed" == "$candidate" ]] || die "Active HEAD does not match validated Lab commit after fast-forward."
write_state previous-commit "$last_good"
write_state active-commit "$deployed"
write_state deployed-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write_state validation-pending "$deployed"

sleep 2
kill -0 "$active_pid" 2>/dev/null ||
  die "Active Hydra PID $active_pid exited after file update. Rollback remains available."
log "Lab commit $deployed is installed. Quickshell watches QML files and reloads on change."
if $YES; then
  echo "After visual/behavior validation run:"
  echo "  Scripts/dev/lab-mark-good.sh $deployed --visual-confirmed"
else
  read -r -p "Did the active Hydra reload and pass visual/behavior validation? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || {
    echo "Not marked good. Roll back with Scripts/dev/lab-rollback.sh." >&2
    exit 1
  }
  "$LAB_DIR/Scripts/dev/lab-mark-good.sh" "$deployed" --visual-confirmed
fi
