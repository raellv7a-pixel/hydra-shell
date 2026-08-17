#!/usr/bin/env -S bash
#
# Mostra, lado a lado, o estado do Lab (checkout de desenvolvimento), da
# shell ativa (~/.config/quickshell/hydra-shell) e do origin/legacy-v4 — para
# saber em um olhar se há trabalho no Lab ainda não publicado, ou se a shell
# ativa está atrás do que já foi validado.
#
# Uso: Scripts/dev/lab-status.sh
set -euo pipefail

BRANCH="legacy-v4"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIVE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hydra-shell"

section() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
warn()    { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

section "Lab — $LAB_DIR"
git -C "$LAB_DIR" fetch origin "$BRANCH" -q || warn "fetch falhou (offline?)"
git -C "$LAB_DIR" status -sb
printf 'HEAD: %s — %s\n' \
  "$(git -C "$LAB_DIR" rev-parse --short HEAD)" \
  "$(git -C "$LAB_DIR" log -1 --format=%s)"

if [ -d "$ACTIVE_DIR/.git" ]; then
  section "Ativa — $ACTIVE_DIR"
  git -C "$ACTIVE_DIR" status -sb
  printf 'HEAD: %s — %s\n' \
    "$(git -C "$ACTIVE_DIR" rev-parse --short HEAD)" \
    "$(git -C "$ACTIVE_DIR" log -1 --format=%s)"

  ahead=$(git -C "$LAB_DIR" rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo '?')
  behind=$(git -C "$ACTIVE_DIR" rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo '?')

  section "Diferença"
  echo "Commits no Lab ainda não publicados em origin/$BRANCH: $ahead"
  echo "Commits que a shell ativa está atrás de origin/$BRANCH: $behind"
  if [ "$ahead" != "0" ]; then
    echo "  -> valide com lab-preview.sh e rode lab-sync.sh quando estiver pronto."
  fi
  if [ "$behind" != "0" ]; then
    echo "  -> a shell ativa está desatualizada; lab-sync.sh também resolve isso."
  fi
else
  warn "Nenhuma instalação ativa em $ACTIVE_DIR (rode Scripts/bash/install.sh)."
fi

if command -v prowl-agent >/dev/null 2>&1; then
  section "prowl-agent wip (Lab)"
  (cd "$LAB_DIR" && prowl-agent wip) || true
fi
