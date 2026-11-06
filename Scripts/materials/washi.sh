#!/usr/bin/env bash
# Adapted from iNiR scripts/colors/washi.sh (GPL-3.0),
# d9ec3eae11b5c8fe51fe0ea362b1fd4d14db1b8c. Only paths/build scope change.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hydra/iris/bin"
bin="$bin_dir/hydra-washi"

stale() {
  [[ -x "$bin" ]] || return 0
  local src
  for src in "$here"/washi/*.go; do
    [[ "$src" == *_test.go ]] && continue
    [[ "$src" -nt "$bin" ]] && return 0
  done
  return 1
}

if stale; then
  go_bin="$(command -v go || true)"
  if [[ -z "$go_bin" ]]; then
    [[ -x "$bin" ]] || { echo "washi: Go is not installed; keeping the last/default palette" >&2; exit 3; }
  else
    mkdir -p "$bin_dir"
    tmp="$bin_dir/.hydra-washi.$$"
    if (cd "$here/washi" && GO111MODULE=off "$go_bin" build -trimpath -o "$tmp" colour.go language.go iris.go material.go washi.go main.go) >&2; then
      mv -f "$tmp" "$bin"
    else
      rm -f "$tmp"
      [[ -x "$bin" ]] || exit 4
    fi
  fi
fi

exec "$bin" "$@"
