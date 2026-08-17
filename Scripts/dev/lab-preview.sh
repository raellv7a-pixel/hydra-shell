#!/usr/bin/env -S bash
#
# Sobe uma instância isolada do hydra-shell a partir do Lab (checkout de
# desenvolvimento), sem tocar na shell ativa que roda em
# ~/.config/quickshell/hydra-shell.
#
# `qs -p <dir>` identifica a config pelo caminho, não pelo nome "hydra-shell"
# usado pela instância ativa (`qs -c hydra-shell`) — por isso as duas rodam
# lado a lado sem o guard --no-duplicate barrar uma da outra. As duas UIs
# ficam sobrepostas na tela enquanto o preview estiver de pé; feche com
# Ctrl+C quando terminar de validar.
#
# Uso: Scripts/dev/lab-preview.sh [args extras para qs]
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command -v qs >/dev/null 2>&1 || {
  echo "qs (noctalia-qs) não encontrado no PATH." >&2
  exit 1
}

echo "==> Preview do Lab: $LAB_DIR"
echo "==> A shell ativa (qs -c hydra-shell), se estiver rodando, continua intacta."
echo "==> Ctrl+C encerra só este preview."
exec qs -p "$LAB_DIR" "$@"
