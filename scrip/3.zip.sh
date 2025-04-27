#!/usr/bin/env bash
source "$(dirname "$0")/fn_compress.sh"
source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

while true; do
  srcdir=$(sleep_until_dirs "$BASE_DIR/3.zip")
  name=$(basename "$srcdir")
  log_line "Compressing $name"

  if ! compress_iso "$srcdir"; then
    log_line "❌ compress_iso failed for $name"
    move_dir_fail "$srcdir" "$BASE_DIR/3.zip.failed"
    continue
  fi

  move_dir_success "$srcdir" "$BASE_DIR/4.ship"
  log_line "✓ Finished compressing $name"
done
