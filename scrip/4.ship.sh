#!/usr/bin/env bash
source "$(dirname "$0")/lib_upload.sh"
source "$(dirname "$0")/lib_log.sh"
source "$(dirname "$0")/lib_queue.sh"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while true; do
  srcdir=$(sleep_until_dirs "$BASE_DIR/4.ship")
  name=$(basename "$srcdir")
  log_line "Uploading $name"

  if ! upload_directory "$srcdir"; then
    log_line "❌ upload_directory failed for $name"
    move_dir_fail "$srcdir" "$BASE_DIR/4.ship.failed"
    continue
  fi

  move_dir_success "$srcdir" "$BASE_DIR/5.sip"
  log_line "✓ Finished uploading $name"
done
