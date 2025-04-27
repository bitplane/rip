#!/usr/bin/env bash

tail_last_log_lines() {
  local logfile="$1"
  echo "---- Last log lines ----"
  if [[ -f "$logfile" ]]; then
    tail -n 10 "$logfile"
  else
    echo "(No log yet)"
  fi
  echo
}

dir_counts_summary() {
  local base_dir="$1"
  echo "---- Queue status ----"

  for queue in ?.*; do
    count=$(find "$base_dir/$queue" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    printf "%-15s: %s\n" "$queue" "$count"
  done

  echo
}
