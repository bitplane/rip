#!/usr/bin/env bash

# scrip/3.zip.sh
# Stage 3: compress the ripped+stripped ISOs into .xz files

source "$(dirname "$0")/fn_compress.sh"
source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"

# Project root (one level up from scrip/)
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

process_zip() {
  local srcdir="$1"
  local name
  name="$(basename "$srcdir")"

  log_line "→ compress_iso for $name"
  if ! compress_iso "$srcdir"; then
    log_line "❌ compress_iso failed for $name"
    return 1
  fi

  log_line "✓ compress_iso succeeded for $name"
}

while true; do
  srcdir=$(sleep_until_dirs "$BASE_DIR/3.zip")
  name="$(basename "$srcdir")"
  log_line "Compressing $name..."

  if ! process_zip "$srcdir"; then
    move_dir_fail "$srcdir" "$BASE_DIR/3.zip.failed"
    continue
  fi

  move_dir_success "$srcdir" "$BASE_DIR/4.ship"
done
