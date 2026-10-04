#!/usr/bin/env bash
# Build Hydra's focus/modifier bridge against the installed Qt ABI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cmake -S "$ROOT/Native" -B "$ROOT/Native/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT/Native/build" --parallel 2
