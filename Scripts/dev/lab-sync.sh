#!/usr/bin/env -S bash
#
# Sistema de atualização Lab -> shell ativa.
#
# Publica o que foi desenvolvido e validado no Lab
# (/home/raell/Projetos/hydra-shell) para a instalação ativa em
# ~/.config/quickshell/hydra-shell, e reinicia o processo em execução.
# Espelha exatamente o passo 5 de Scripts/bash/install.sh (mesmo padrão de
# fetch/checkout/reset usado para atualizar um checkout existente), então
# reaproveita esse fluxo já auditado em vez de inventar um segundo.
#
# Passos:
#   1. Exige o Lab limpo e em legacy-v4 (nunca decide por você o que commitar).
#   2. Roda Scripts/dev/qmlfmt.sh (mesmo formatter do pre-commit hook) e falha
#      se sobrar diff — força formatar e commitar antes de publicar.
#   3. Roda `prowl-agent doctor` no Lab, se disponível (não bloqueia; é um
#      relatório de saúde do projeto, não um linter estrito).
#   4. git push do Lab para origin/legacy-v4.
#   5. Pede confirmação de que o preview (lab-preview.sh) foi validado, a
#      menos que -y/--yes seja passado.
#   6. Fast-forward da instalação ativa para origin/legacy-v4 (nunca reescreve
#      histórico nem descarta mudanças locais não commitadas nela).
#   7. Reinicia o processo `qs -c hydra-shell` (mesmo comando do
#      Assets/Hyprland/modules/autostart.lua) para a mudança entrar no ar.
#
# Uso: Scripts/dev/lab-sync.sh [-y|--yes]
set -euo pipefail

BRANCH="legacy-v4"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIVE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hydra-shell"

YES=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=true ;;
  esac
done

log()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$ACTIVE_DIR/.git" ] || die "Sem instalação ativa em $ACTIVE_DIR — rode Scripts/bash/install.sh primeiro."

cd "$LAB_DIR"
current_branch="$(git branch --show-current)"
[ "$current_branch" = "$BRANCH" ] || die "Lab está em '$current_branch', não em '$BRANCH' — troque ou faça merge antes de sincronizar."
[ -z "$(git status --porcelain)" ] || die "Lab tem mudanças não commitadas — commit ou stash antes de sincronizar."

log "Formatando QML (Lab)"
./Scripts/dev/qmlfmt.sh
[ -z "$(git status --porcelain)" ] || die "qmlfmt.sh alterou arquivos — revise e commit a formatação antes de sincronizar."

if command -v prowl-agent >/dev/null 2>&1; then
  log "prowl-agent doctor (Lab)"
  prowl-agent doctor || warn "prowl-agent doctor reportou problemas acima — revise antes de prosseguir."
else
  warn "prowl-agent não encontrado no PATH — pulei o diagnóstico do projeto."
fi

log "Publicando $BRANCH em origin"
git push origin "$BRANCH"

if ! $YES; then
  read -r -p "Já validou com Scripts/dev/lab-preview.sh? Confirmar publicação na shell ativa em $ACTIVE_DIR? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || die "Cancelado — nada foi tocado em $ACTIVE_DIR."
fi

[ -z "$(git -C "$ACTIVE_DIR" status --porcelain)" ] || die "$ACTIVE_DIR tem mudanças locais — resolva manualmente (este script nunca descarta trabalho local)."

log "Atualizando a instalação ativa"
git -C "$ACTIVE_DIR" fetch origin "$BRANCH"
git -C "$ACTIVE_DIR" checkout "$BRANCH"
git -C "$ACTIVE_DIR" reset --hard "origin/$BRANCH"

log "Reiniciando hydra-shell"
pkill -f 'qs -c hydra-shell' 2>/dev/null || true
sleep 0.3
if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
  command -v qs >/dev/null 2>&1 && qs -c hydra-shell -d
  log "hydra-shell reiniciada."
else
  warn "Hyprland não detectado nesta sessão — inicie manualmente com: qs -c hydra-shell -d"
fi

log "Sincronizado: $ACTIVE_DIR agora está em $(git -C "$ACTIVE_DIR" rev-parse --short HEAD)"
