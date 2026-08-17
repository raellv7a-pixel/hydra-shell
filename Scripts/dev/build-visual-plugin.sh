#!/usr/bin/env -S bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${HYDRA_VISUAL_BUILD_DIR:-$ROOT/.build/visual-plugin}"
PREFIX="${HYDRA_VISUAL_PREFIX:-$ROOT/.build/visual-install}"

if [[ ${1:-} == "--prefix" ]]; then
  [[ -n ${2:-} ]] || { echo "--prefix requires a path" >&2; exit 2; }
  PREFIX="$2"
  shift 2
fi
[[ $# -eq 0 ]] || { echo "Usage: $0 [--prefix PATH]" >&2; exit 2; }

for tool in cmake ninja; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$tool is required to build Hydra.Visual" >&2
    exit 1
  }
done

cmake -S "$ROOT/plugin" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build "$BUILD_DIR" --parallel "${HYDRA_BUILD_JOBS:-$(nproc)}"
cmake --install "$BUILD_DIR" --prefix "$PREFIX"

printf 'Hydra.Visual installed in %s/lib/qt6/qml\n' "$PREFIX"
