#!/usr/bin/env bash

move_dir_success() {
  local src_dir="$1"
  local dest_dir="$2"
  mv "$src_dir" "$dest_dir/" && log_line "Moved $(basename "$src_dir") to $dest_dir"
}

move_dir_fail() {
  local src_dir="$1"
  local fail_dir="$2"
  mv "$src_dir" "$fail_dir/" && log_line "Moved $(basename "$src_dir") to $fail_dir (FAIL)"
  send_alert "Failure: Moved $(basename "$src_dir") to $fail_dir"
}

count_dirs() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l
}

sleep_until_dirs() {
  local dir="$1"
  while [[ $(count_dirs "$dir") -eq 0 ]]; do
    sleep 5
  done
}
