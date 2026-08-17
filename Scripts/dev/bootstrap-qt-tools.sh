#!/usr/bin/env -S bash
set -euo pipefail

# Installs the exact Qt tooling used by Hydra development into the user's
# cache. Nothing is installed system-wide and no sudo access is required.
# qmlformat 6.11.1 currently shipped by Arch/CachyOS silently fails on valid
# project files, while the pinned 6.10.3 tool formats the full tree.

QT_VERSION="6.10.3"
TOOLS_HOME="${HYDRA_TOOLS_HOME:-$HOME/.cache/hydra-shell-tools}"
QT_ROOT="${HYDRA_QT_TOOLS_DIR:-$TOOLS_HOME/qt}"
VENV="$TOOLS_HOME/aqt-venv"
QMLFORMAT="$QT_ROOT/$QT_VERSION/gcc_64/bin/qmlformat"
AQT_VERSION="3.3.0"

if [ -x "$QMLFORMAT" ] && [ "$($QMLFORMAT --version 2>&1)" = "qmlformat $QT_VERSION" ]; then
  echo "Qt tools already ready: $QMLFORMAT"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required to bootstrap the pinned Qt tools." >&2
  exit 1
}

mkdir -p "$TOOLS_HOME"
if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install --disable-pip-version-check --quiet "aqtinstall==$AQT_VERSION"
"$VENV/bin/aqt" install-qt linux desktop "$QT_VERSION" linux_gcc_64 -O "$QT_ROOT"

actual="$($QMLFORMAT --version 2>&1)"
[ "$actual" = "qmlformat $QT_VERSION" ] || {
  echo "Unexpected qmlformat after bootstrap: $actual" >&2
  exit 1
}
echo "Qt tools ready: $QMLFORMAT"
