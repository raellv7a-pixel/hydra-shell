#!/usr/bin/env bash
# Run Qt's QML linter with Quickshell's generated type metadata and Hydra's qs.* modules.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

changed_qml=()
for qml_path in "$@"; do
  [[ "$qml_path" == *.qml && -f "$LAB_DIR/$qml_path" ]] || continue
  changed_qml+=("$qml_path")
done
((${#changed_qml[@]})) || exit 0

qml_lint="${HYDRA_QT_TOOLS_DIR:-$HOME/.cache/hydra-shell-tools/qt}/6.10.3/gcc_64/bin/qmllint"
[[ -x "$qml_lint" ]] || qml_lint="$(command -v qmllint || true)"
[[ -n "$qml_lint" ]] || die "Changed QML requires qmllint; install the pinned Qt tools."

quickshell_qml_modules="${HYDRA_QUICKSHELL_QML_MODULES_DIR:-}"
if [[ -n "$quickshell_qml_modules" ]]; then
  [[ -f "$quickshell_qml_modules/Quickshell/qmldir" ]] ||
    die "HYDRA_QUICKSHELL_QML_MODULES_DIR must contain Quickshell/qmldir."
else
  qml_module_candidates=()
  qtpaths="${qml_lint%/*}/qtpaths"
  if [[ ! -x "$qtpaths" ]]; then
    qtpaths="$(command -v qtpaths6 || command -v qtpaths || true)"
  fi
  if [[ -n "$qtpaths" ]]; then
    qt_qml_path="$("$qtpaths" --query QT_INSTALL_QML 2>/dev/null || true)"
    [[ -z "$qt_qml_path" ]] || qml_module_candidates+=("$qt_qml_path")
  fi
  IFS=: read -r -a env_qml_paths <<< "${QML_IMPORT_PATH:-}:${QML2_IMPORT_PATH:-}"
  qml_module_candidates+=("${env_qml_paths[@]}")
  for candidate in "${qml_module_candidates[@]}"; do
    if [[ -f "$candidate/Quickshell/qmldir" ]]; then
      quickshell_qml_modules="$candidate"
      break
    fi
  done
fi

if [[ -z "$quickshell_qml_modules" ]]; then
  cached_qml_modules=()
  for candidate in "$HOME"/.cache/hydra-shell-build/*/qml_modules; do
    [[ -f "$candidate/Quickshell/qmldir" ]] && cached_qml_modules+=("$candidate")
  done
  ((${#cached_qml_modules[@]} <= 1)) ||
    die "Multiple cached Quickshell builds found; set HYDRA_QUICKSHELL_QML_MODULES_DIR to the active build's qml_modules directory."
  ((${#cached_qml_modules[@]} == 1)) && quickshell_qml_modules="${cached_qml_modules[0]}"
fi
[[ -f "$quickshell_qml_modules/Quickshell/qmldir" ]] ||
  die "Quickshell QML type metadata not found; set HYDRA_QUICKSHELL_QML_MODULES_DIR to its qml_modules directory."

qml_import_root="$(mktemp -d "${TMPDIR:-/tmp}/hydra-qml-imports.XXXXXX")"
trap 'rm -rf -- "$qml_import_root"' EXIT
while IFS= read -r -d '' source_path; do
  source_file="$LAB_DIR/$source_path"
  [[ -f "$source_file" ]] || continue
  source_dir="${source_path%/*}"
  [[ "$source_dir" != "$source_path" ]] || source_dir=.
  source_name="${source_path##*/}"
  module_uri=qs
  module_dir="$qml_import_root/qs"
  if [[ "$source_dir" != . ]]; then
    module_uri+=".${source_dir//\//.}"
    module_dir+="/$source_dir"
  fi
  mkdir -p "$module_dir"
  if [[ ! -f "$module_dir/qmldir" ]]; then
    printf 'module %s\n' "$module_uri" >"$module_dir/qmldir"
  fi
  ln -s -- "$source_file" "$module_dir/$source_name"
  if [[ "$source_name" == *.qml ]]; then
    type_name="${source_name%.qml}"
    if [[ "$type_name" =~ ^[A-Z][A-Za-z0-9_]*$ ]]; then
      if grep -Eq '^[[:space:]]*pragma[[:space:]]+Singleton([[:space:]]|$)' "$source_file"; then
        printf 'singleton %s 1.0 %s\n' "$type_name" "$source_name" >>"$module_dir/qmldir"
      else
        printf '%s 1.0 %s\n' "$type_name" "$source_name" >>"$module_dir/qmldir"
      fi
    fi
  fi
done < <(git -C "$LAB_DIR" ls-files -z --cached --others --exclude-standard -- '*.qml' '*.js')

printf 'Checking QML imports with Quickshell and Hydra module metadata...\n'
(cd "$LAB_DIR" && "$qml_lint" --import error \
  -I "$quickshell_qml_modules" -I "$qml_import_root" -I "$LAB_DIR" "${changed_qml[@]}")
