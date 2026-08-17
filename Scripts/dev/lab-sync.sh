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
#      se sobrar diff — força formatar e commitar antes de publicar. Pule com
#      --skip-format só se o `qmlformat` instalado nesta máquina estiver
#      quebrado (ex.: versão do qt6-declarative com regressão conhecida —
#      visto com 6.11.1 do repo Arch, que falha silenciosamente, exit 1 sem
#      stderr, em alguns arquivos, e reformata em massa os demais com um
#      estilo diferente do commitado). Formate à mão os arquivos tocados
#      nesse caso; nunca commit um reformat em massa sem revisar o diff.
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
# Uso: Scripts/dev/lab-sync.sh [-y|--yes] [--skip-format]
set -euo pipefail

BRANCH="legacy-v4"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIVE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hydra-shell"

YES=false
SKIP_FORMAT=false
for arg in "$@"; do
  case "$arg" in
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

if $SKIP_FORMAT; then
  warn "--skip-format: pulei o Scripts/dev/qmlfmt.sh. Garanta à mão que o que você tocou está formatado."
else
  log "Formatando QML (Lab)"
  ./Scripts/dev/qmlfmt.sh
  [ -z "$(git status --porcelain)" ] || die "qmlfmt.sh alterou arquivos — revise e commit a formatação antes de sincronizar."
fi

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
if pgrep -x qs >/dev/null 2>&1; then
  pkill -x qs
  for _ in $(seq 1 20); do
    pgrep -x qs >/dev/null 2>&1 || break
    sleep 0.2
  done
  pgrep -x qs >/dev/null 2>&1 && { warn "qs não saiu a tempo, forçando"; pkill -9 -x qs; sleep 0.3; }
fi

# O --no-duplicate padrão do qs decide se já há instância rodando checando o
# PID gravado em $XDG_RUNTIME_DIR/quickshell/by-pid/<pid>; um lock deixado
# por um processo morto sem limpeza (crash, SIGKILL) pode fazer o próximo
# `qs -c hydra-shell -d` recusar a subir, ou pior, subir uma segunda
# instância disputando os mesmos arquivos de settings/estado. Remove só as
# entradas cujo PID está comprovadamente morto antes de relançar.
QS_BYPID_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-pid"
if [ -d "$QS_BYPID_DIR" ]; then
  for pidlink in "$QS_BYPID_DIR"/*; do
    [ -e "$pidlink" ] || continue
    pid="$(basename "$pidlink")"
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -rf "$(readlink -f "$pidlink")" "$pidlink"
    fi
  done
fi

if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
  command -v qs >/dev/null 2>&1 && qs -c hydra-shell -d
  sleep 0.5
  if pgrep -x qs >/dev/null 2>&1; then
    log "hydra-shell reiniciada (PID $(pgrep -x qs | tr '\n' ' '))."
  else
    warn "qs -c hydra-shell -d rodou mas nenhum processo ficou de pé — confira \$XDG_RUNTIME_DIR/quickshell/by-id/*/log.log"
  fi
else
  warn "Hyprland não detectado nesta sessão — inicie manualmente com: qs -c hydra-shell -d"
fi

log "Sincronizado: $ACTIVE_DIR agora está em $(git -C "$ACTIVE_DIR" rev-parse --short HEAD)"
