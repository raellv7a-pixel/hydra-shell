#!/usr/bin/env bash
#
# corvus-share-picker — ponte entre o xdg-desktop-portal-hyprland e o painel de
# compartilhamento de tela do Corvus Shell.
#
# O xdph executa este script e lê o stdout de forma síncrona. Como a shell já
# está rodando e não pode ser o binário do picker, aqui criamos um FIFO, pedimos
# à shell (via IPC) que abra o painel, e bloqueamos esperando a seleção.
#
# Contrato do xdph (src/shared/ScreencopyShared.cpp, v1.4.1):
#   stdout: [SELECTION]<flags>/<seleção>\n
#     flags       'r' permite token de restauração, vazio caso contrário
#     screen:NOME  o xdph faz pop_back() no nome -> o \n final é obrigatório
#     window:ID    decimal, 32 bits baixos do handle do toplevel
#     region:NOME@x,y,w,h  coordenadas locais à tela, em pixels lógicos
#   Sair sem imprimir [SELECTION] equivale a cancelar.
#
# Se qualquer coisa der errado, caímos no picker oficial: compartilhar tela
# nunca pode quebrar.

set -uo pipefail

readonly SHELL_CONFIG="hydra-shell"
readonly WAIT_SECONDS=300

fallback() {
  local official
  official=$(command -v hyprland-share-picker || true)
  if [[ -n $official ]]; then
    exec "$official" "$@"
  fi
  # Sem picker oficial: sair silenciosamente equivale a cancelar.
  exit 0
}

# --- área de trabalho ---------------------------------------------------------

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/corvus-share-picker"
mkdir -p "$runtime_dir" 2>/dev/null || fallback "$@"

request_id="$$-${RANDOM}"
fifo="$runtime_dir/$request_id.fifo"
list_file="$runtime_dir/$request_id.list"

cleanup() { rm -f "$fifo" "$list_file"; }
trap cleanup EXIT

# A lista de janelas vai por arquivo, não por argumento: ela contém separadores
# como [HC>] e títulos arbitrários, que não sobreviveriam bem a um argv de IPC.
printf '%s' "${XDPH_WINDOW_SHARING_LIST:-}" >"$list_file" 2>/dev/null || fallback "$@"

mkfifo "$fifo" 2>/dev/null || fallback "$@"

allow_token=0
for arg in "$@"; do
  [[ $arg == "--allow-token" ]] && allow_token=1
done

# --- aciona a shell -----------------------------------------------------------

# Atenção: `qs ipc call` sai com 0 mesmo quando o target não existe (imprime
# "Target not found."). Por isso validamos o valor retornado pelo handler, e não
# o código de saída.
response=$(qs -c "$SHELL_CONFIG" ipc call screenshare open \
  "$fifo" "$list_file" "$allow_token" 2>/dev/null)

if [[ ${response//[[:space:]]/} != "ok" ]]; then
  fallback "$@"
fi

# --- espera a seleção ---------------------------------------------------------

# `cat` bloqueia na abertura do FIFO até a shell escrever. O timeout é apenas
# rede de segurança para o caso de a shell morrer com o painel aberto.
selection=$(timeout "$WAIT_SECONDS" cat "$fifo") || exit 0

# Cancelamento: a shell escreve payload vazio só para destravar este processo.
[[ -z ${selection//[[:space:]]/} ]] && exit 0

# A substituição de comando já removeu quebras de linha finais; o printf
# recoloca exatamente uma, que é o que o pop_back() do xdph consome.
printf '%s\n' "$selection"
