#!/usr/bin/env bash

source "$(dirname "$0")/fn_compress.sh"
source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"

BASE_DIR="$(dirname "$(dirname "$0")")"

process_zip() {
  local srcdir="$1"

  local iso
  iso=$(find "$srcdir" -maxdepth 1 -name '*.iso' | head -n1)
  if [[ -z "$iso" ]]; then
    log_line "❌ No ISO found in $srcdir"
    return 1
  fi

  compress_iso "$iso" "$srcdir" || return 1

  rm "$iso"
}

while true; do
  srcdir=$(find "$BASE_DIR/1.rip/" -mindepth 1 -maxdepth 1 -type d | head -n1)
  [[ -z "$srcdir" ]] && sleep 5 && continue

  log_line "Compressing $srcdir"

  if ! process_zip "$srcdir"; then
    log_line "❌ Compression failed for $(basename "$srcdir")"
    move_dir_fail "$srcdir" "$BASE_DIR/2.zip.failed"
    continue
  fi

  move_dir_success "$srcdir" "$BASE_DIR/2.zip"
  log_line "✓ Finished compressing $(basename "$srcdir")"
done
