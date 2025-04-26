#!/usr/bin/env bash


source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"
source "$(dirname "$0")/fn_upload_ia.sh"

while true; do
  srcdir=$(find 2.zip/ -mindepth 1 -maxdepth 1 -type d | head -n1)
  [[ -z "$srcdir" ]] && sleep 5 && continue

  log_line "Uploading $srcdir"

  if upload_directory "$srcdir"; then
    move_dir_success "$srcdir" "4.done"
  else
    move_dir_fail "$srcdir" "3.ship.failed"
  fi
done

