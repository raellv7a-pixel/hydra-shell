#!/usr/bin/env -S bash
set -euo pipefail

# QML formatter. Formatting is transactional: every file is copied to a
# temporary tree and formatted there first. The working tree is updated only
# after every qmlformat process succeeds, so a parser regression can never
# leave a half-formatted repository behind.
#
# Usage:
#   Scripts/dev/qmlfmt.sh                  # format every QML file
#   Scripts/dev/qmlfmt.sh --check          # fail if formatting would change
#   Scripts/dev/qmlfmt.sh [--check] PATH…  # limit to files/directories

export QT_LOGGING_RULES="qt.qmldom.*=false"

PINNED_QT_VERSION="6.10.3"
PINNED_QT_ROOT="${HYDRA_QT_TOOLS_DIR:-$HOME/.cache/hydra-shell-tools/qt}"
QMLFORMAT="${HYDRA_QMLFORMAT:-}"
if [ -z "$QMLFORMAT" ] && [ -x "$PINNED_QT_ROOT/$PINNED_QT_VERSION/gcc_64/bin/qmlformat" ]; then
  QMLFORMAT="$PINNED_QT_ROOT/$PINNED_QT_VERSION/gcc_64/bin/qmlformat"
fi
if [ -z "$QMLFORMAT" ]; then
  for path in "/usr/lib64/qt6/bin/qmlformat" "/usr/lib/qt6/bin/qmlformat"; do
    if [ -x "$path" ]; then
      QMLFORMAT="$path"
      break
    fi
  done
fi
if [ -z "$QMLFORMAT" ] && command -v qmlformat &>/dev/null; then
  QMLFORMAT="$(command -v qmlformat)"
fi
if [ -z "$QMLFORMAT" ]; then
  echo "No 'qmlformat' found. Run Scripts/dev/bootstrap-qt-tools.sh." >&2
  exit 1
fi

CHECK=false
targets=()
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=true ;;
    -h|--help)
      sed -n '5,12p' "$0"
      exit 0
      ;;
    *) targets+=("$arg") ;;
  esac
done
[ ${#targets[@]} -gt 0 ] || targets=(".")

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hydra-qmlfmt.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

EXTRA_FLAGS=""
version="$("$QMLFORMAT" --version 2>&1 || true)"
if [[ "$version" =~ ([0-9]+\.[0-9]+) ]] &&
   [[ "$(printf '%s\n6.10\n' "${BASH_REMATCH[1]}" | sort -V | head -1)" == "6.10" ]]; then
  EXTRA_FLAGS="-S --semicolon-rule always"
fi

all_files=()
for target in "${targets[@]}"; do
  if [ -d "$target" ]; then
    while IFS= read -r -d '' file; do all_files+=("$file"); done \
      < <(find "$target" -name "*.qml" -type f -print0)
  elif [ -f "$target" ] && [[ "$target" == *.qml ]]; then
    all_files+=("$target")
  else
    echo "Ignoring non-QML target: $target" >&2
  fi
done
[ ${#all_files[@]} -gt 0 ] || { echo "No QML files found"; exit 0; }

format_copy() {
  local source="$1" absolute relative destination
  absolute="$(realpath "$source")"
  relative="${absolute#"$REPO_ROOT"/}"
  destination="$TMP_DIR/$relative"
  mkdir -p "$(dirname "$destination")"
  cp -p "$absolute" "$destination"
  if ! "$QMLFORMAT" -w 2 -W 360 $EXTRA_FLAGS -i "$destination"; then
    echo "Failed: $relative ($version)" >&2
    return 1
  fi
}
export -f format_copy
export QMLFORMAT EXTRA_FLAGS REPO_ROOT TMP_DIR version

echo "Formatting ${#all_files[@]} files transactionally with $version..."
if ! printf '%s\0' "${all_files[@]}" |
  xargs -0 -P "${QMLFMT_JOBS:-$(nproc)}" -I {} bash -c 'format_copy "$1"' _ {}; then
  echo "Errors occurred; working tree left untouched." >&2
  exit 1
fi

changed=()
for source in "${all_files[@]}"; do
  absolute="$(realpath "$source")"
  relative="${absolute#"$REPO_ROOT"/}"
  destination="$TMP_DIR/$relative"
  cmp -s "$absolute" "$destination" || changed+=("$relative")
done

if $CHECK; then
  if [ ${#changed[@]} -gt 0 ]; then
    printf 'Would reformat: %s\n' "${changed[@]}" >&2
    exit 1
  fi
  echo "Done; all QML files already formatted."
  exit 0
fi

for relative in "${changed[@]}"; do
  cp -p "$TMP_DIR/$relative" "$REPO_ROOT/$relative"
done
echo "Done; reformatted ${#changed[@]} file(s)."
