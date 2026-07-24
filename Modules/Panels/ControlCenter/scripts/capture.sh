#!/usr/bin/env bash
set -u

state_file="${XDG_RUNTIME_DIR:-/tmp}/raell-dashboard-record.state"

write_state() {
  local state="${1:-}"
  local output="${2:-}"
  local format="${3:-}"
  local pid="${4:-}"

  {
    printf 'state=%s\n' "$state"
    printf 'output=%s\n' "$output"
    printf 'format=%s\n' "$format"
    printf 'pid=%s\n' "$pid"
  } > "$state_file"
}

clear_state_later() {
  sleep 4
  rm -f "$state_file"
}

record_status() {
  if [ ! -f "$state_file" ]; then
    printf '\n'
    return 0
  fi

  # shellcheck disable=SC1090
  . "$state_file" 2>/dev/null || true
  printf '%s|%s|%s\n' "${state:-}" "${output:-}" "${format:-}"
}

stop_recording() {
  if [ -f "$state_file" ]; then
    # shellcheck disable=SC1090
    . "$state_file" 2>/dev/null || true
    if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
      kill -INT "$pid" 2>/dev/null || true
      return 0
    fi
  fi

  pkill -INT wf-recorder 2>/dev/null || true
}

start_recording() {
  local format="${1:-gif}"
  if [ "$format" != "mp4" ]; then
    format="gif"
  fi

  if [ -f "$state_file" ]; then
    # shellcheck disable=SC1090
    . "$state_file" 2>/dev/null || true
    if [ "${state:-}" = "recording" ] && [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi

  if ! command -v slurp >/dev/null 2>&1 || ! command -v wf-recorder >/dev/null 2>&1; then
    write_state "failed" "" "$format" ""
    clear_state_later
    return 1
  fi

  write_state "selecting" "" "$format" ""
  local region
  region="$(slurp)" || {
    rm -f "$state_file"
    return 1
  }

  local videos_dir="${HOME:-/tmp}/Videos"
  mkdir -p "$videos_dir"

  local stamp
  stamp="$(date +%Y-%m-%d_%H-%M-%S)"
  local tmp="/tmp/raell-dashboard-record-${stamp}-$$.mp4"
  local output="$videos_dir/raell-capture-${stamp}.${format}"

  wf-recorder -g "$region" -f "$tmp" >/dev/null 2>&1 &
  local rec_pid=$!
  write_state "recording" "$output" "$format" "$rec_pid"
  wait "$rec_pid" || true

  if [ ! -s "$tmp" ]; then
    write_state "failed" "$output" "$format" ""
    clear_state_later
    return 1
  fi

  write_state "converting" "$output" "$format" ""
  if [ "$format" = "mp4" ]; then
    mv "$tmp" "$output"
  else
    ffmpeg -y -i "$tmp" \
      -vf 'fps=15,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse' \
      "$output" >/dev/null 2>&1
    rm -f "$tmp"
  fi

  if [ -s "$output" ]; then
    write_state "done" "$output" "$format" ""
  else
    write_state "failed" "$output" "$format" ""
  fi
  clear_state_later
}

case "${1:-status}" in
  start)
    start_recording "${2:-gif}"
    ;;
  stop)
    stop_recording
    ;;
  status)
    record_status
    ;;
  *)
    printf 'usage: %s {start gif|start mp4|stop|status}\n' "$0" >&2
    exit 2
    ;;
esac
