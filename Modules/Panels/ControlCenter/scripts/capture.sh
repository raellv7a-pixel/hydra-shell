#!/usr/bin/env bash
set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
state_file="${runtime_dir}/hydra-dashboard-record.state"
legacy_state_file="${runtime_dir}/raell-dashboard-record.state"

parsed_state=""
parsed_output=""
parsed_format=""
parsed_pid=""

resolve_active_state_file() {
  if [ -f "$state_file" ]; then
    printf '%s\n' "$state_file"
  elif [ -f "$legacy_state_file" ]; then
    printf '%s\n' "$legacy_state_file"
  else
    printf '%s\n' "$state_file"
  fi
}

parse_state_file() {
  local file="${1:-}"
  parsed_state=""
  parsed_output=""
  parsed_format=""
  parsed_pid=""

  if [ ! -f "$file" ]; then
    return 1
  fi

  local version=""
  local output_b64=""
  local legacy_output=""
  local line key val

  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    case "$line" in
      *=*)
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
          version)
            version="$val"
            ;;
          state)
            parsed_state="$val"
            ;;
          format)
            parsed_format="$val"
            ;;
          pid)
            parsed_pid="$val"
            ;;
          output_b64)
            output_b64="$val"
            ;;
          output)
            legacy_output="$val"
            ;;
        esac
        ;;
    esac
  done < "$file"

  if [ -n "$output_b64" ]; then
    parsed_output="$(printf '%s' "$output_b64" | base64 -d 2>/dev/null || printf '%s' "$output_b64" | base64 --decode 2>/dev/null || true)"
  elif [ -n "$legacy_output" ]; then
    case "$legacy_output" in
      \"*\"|\'*\')
        legacy_output="${legacy_output#?}"
        legacy_output="${legacy_output%?}"
        ;;
    esac
    parsed_output="$legacy_output"
  fi

  case "$parsed_state" in
    selecting|recording|converting|done|failed)
      ;;
    *)
      parsed_state=""
      ;;
  esac

  case "$parsed_format" in
    gif|mp4)
      ;;
    *)
      parsed_format=""
      ;;
  esac

  if [ -n "$parsed_pid" ]; then
    case "$parsed_pid" in
      ''|*[!0-9]*)
        parsed_pid=""
        ;;
      *)
        if [ "$parsed_pid" -le 0 ] 2>/dev/null; then
          parsed_pid=""
        fi
        ;;
    esac
  fi

  return 0
}

write_state() {
  local state="${1:-}"
  local output="${2:-}"
  local format="${3:-}"
  local pid="${4:-}"
  local out_b64
  out_b64="$(printf '%s' "$output" | base64 | tr -d '\r\n')"

  {
    printf 'version=2\n'
    printf 'state=%s\n' "$state"
    printf 'output_b64=%s\n' "$out_b64"
    printf 'format=%s\n' "$format"
    printf 'pid=%s\n' "$pid"
  } > "$state_file"
}

clear_state_later() {
  local target="${1:-$state_file}"
  sleep 4
  rm -f "$target" "$legacy_state_file"
}

record_status() {
  local active_file
  active_file="$(resolve_active_state_file)"
  if [ ! -f "$active_file" ]; then
    printf '\n'
    return 0
  fi

  parse_state_file "$active_file"
  printf '%s|%s|%s\n' "$parsed_state" "$parsed_output" "$parsed_format"
}

stop_recording() {
  local active_file
  active_file="$(resolve_active_state_file)"
  if [ -f "$active_file" ]; then
    parse_state_file "$active_file"
    if [ -n "$parsed_pid" ] && kill -0 "$parsed_pid" 2>/dev/null; then
      kill -INT "$parsed_pid" 2>/dev/null || true
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

  local active_file
  active_file="$(resolve_active_state_file)"
  if [ -f "$active_file" ]; then
    parse_state_file "$active_file"
    if [ "$parsed_state" = "recording" ] && [ -n "$parsed_pid" ] && kill -0 "$parsed_pid" 2>/dev/null; then
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
    rm -f "$state_file" "$legacy_state_file"
    return 1
  }
  local videos_dir="${HOME:-/tmp}/Videos"
  mkdir -p "$videos_dir"

  local stamp
  stamp="$(date +%Y-%m-%d_%H-%M-%S)"
  local tmp="/tmp/hydra-dashboard-record-${stamp}-$$.mp4"
  local output="$videos_dir/hydra-capture-${stamp}.${format}"
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
