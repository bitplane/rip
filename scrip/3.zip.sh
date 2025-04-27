#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scrip/lib_compress.sh"
source "$BASE_DIR/scrip/lib_log.sh"
source "$BASE_DIR/scrip/lib_queue.sh"

while true; do
  srcdir=$(sleep_until_dirs "$BASE_DIR/3.zip")
  name=$(basename "$srcdir")
  log_line "Compressing $name"

  if ! compress_iso "$srcdir"; then
    log_line "❌ compress_iso failed for $name"
    move_dir_fail "$srcdir"
    continue
  fi

  move_dir_success "$srcdir" "$BASE_DIR/4.ship"
  log_line "✓ Finished compressing $name"
done
