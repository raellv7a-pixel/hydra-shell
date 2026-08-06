#!/usr/bin/env bash

set -u

gpu_backend="${1:-none}"
sample_seconds="${2:-0.35}"
page_size_kib=$(( $(getconf PAGESIZE 2>/dev/null || printf '4096') / 1024 ))

declare -A previous_ticks
declare -A process_names
declare -A process_ticks
declare -A process_rss
declare -A process_gpu

read_cpu_total() {
  local label user nice system idle iowait irq softirq steal guest guest_nice
  read -r label user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  printf '%s' "$((user + nice + system + idle + iowait + irq + softirq + steal))"
}

snapshot_process_ticks() {
  local stat_file stat pid name rest
  local -a fields

  for stat_file in /proc/[0-9]*/stat; do
    [[ -r "$stat_file" ]] || continue
    stat=$(<"$stat_file") || continue
    pid=${stat%% *}
    name=${stat#*(}
    name=${name%%)*}
    rest=${stat#*) }
    read -r -a fields <<< "$rest"
    [[ ${#fields[@]} -ge 13 ]] || continue
    previous_ticks["$pid"]=$(( ${fields[11]} + ${fields[12]} ))
  done
}

total_before=$(read_cpu_total)
snapshot_process_ticks
sleep "$sample_seconds"
total_after=$(read_cpu_total)
total_delta=$((total_after - total_before))
(( total_delta > 0 )) || total_delta=1

for stat_file in /proc/[0-9]*/stat; do
  [[ -r "$stat_file" ]] || continue
  stat=$(<"$stat_file") || continue
  pid=${stat%% *}
  [[ -n ${previous_ticks[$pid]+x} ]] || continue
  name=${stat#*(}
  name=${name%%)*}
  rest=${stat#*) }
  read -r -a fields <<< "$rest"
  [[ ${#fields[@]} -ge 22 ]] || continue

  current_ticks=$(( ${fields[11]} + ${fields[12]} ))
  delta=$((current_ticks - previous_ticks[$pid]))
  (( delta >= 0 )) || delta=0
  rss_pages=${fields[21]}
  [[ "$rss_pages" =~ ^[0-9]+$ ]] || rss_pages=0

  process_names["$pid"]="$name"
  process_ticks["$pid"]="$delta"
  process_rss["$pid"]=$((rss_pages * page_size_kib))
  process_gpu["$pid"]=0
done

if [[ "$gpu_backend" == "nvidia" ]] && command -v nvidia-smi >/dev/null 2>&1; then
  while read -r gpu_id pid type sm memory encoder decoder jpeg ofa command rest; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    [[ -n ${process_names[$pid]+x} ]] || continue
    [[ "$sm" =~ ^[0-9]+$ ]] || sm=0
    process_gpu["$pid"]="$sm"
  done < <(nvidia-smi pmon -c 1 -s um 2>/dev/null || true)
fi

for pid in "${!process_names[@]}"; do
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$pid" \
    "${process_names[$pid]}" \
    "${process_ticks[$pid]}" \
    "$total_delta" \
    "${process_rss[$pid]}" \
    "${process_gpu[$pid]}"
done
