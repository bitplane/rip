#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR"/scrip/lib_monitor.sh

while true; do
  clear
  dir_counts_summary "."
  tail_last_log_lines "archive.log"
  sleep 5
done

