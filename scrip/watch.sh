#!/usr/bin/env bash

source "$(dirname "$0")/fn_monitor.sh"

while true; do
  clear
  dir_counts_summary "."
  tail_last_log_lines "archive.log"
  sleep 5
done

