#!/usr/bin/env bash

# scrip/4.ship.sh
# Stage 4: upload compressed ISOs (and metadata) to Internet Archive

source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"
source "$(dirname "$0")/fn_upload_ia.sh"

# Project root is one level up from this script
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

process_ship() {
  local srcdir="$1"
  local name
  name="$(basename "$srcdir")"

  log_line "→ upload_directory for $name"
  if ! upload_directory "$srcdir"; then
    log_line "❌ upload_directory failed for $name"
    return 1
  fi

  log_line "✓ upload_directory succeeded for $name"
}

while true; do
  srcdir=$(sleep_until_dirs "$BASE_DIR/4.ship")
  name="$(basename "$srcdir")"
  log_line "Uploading $name..."

  if ! process_ship "$srcdir"; then
    move_dir_fail "$srcdir" "$BASE_DIR/4.ship.failed"
    continue
  fi

  move_dir_success "$srcdir" "$BASE_DIR/5.done"
done
