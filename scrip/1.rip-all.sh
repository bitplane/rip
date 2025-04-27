#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scrip/libs.sh"

pids=()
trap 'kill ${pids[@]} 2>/dev/null; exit 1' INT TERM

drives=($@)
[ ${#drives[@]} -eq 0 ] && drives=($(drive_list))
[ ${#drives[@]} -eq 0 ] && drives=("/dev/sr0")

for drive in "${drives[@]}"; do
  "$BASE_DIR/scrip/1.rip.sh" "$drive" &
  pids+=($!)
done

wait
