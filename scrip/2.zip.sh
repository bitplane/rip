#!/usr/bin/env bash


source "$(dirname "$0")/fn_mount.sh"
source "$(dirname "$0")/fn_fileinfo.sh"
source "$(dirname "$0")/fn_compress.sh"
source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"

while true; do
  srcdir=$(find 1.rip/ -mindepth 1 -maxdepth 1 -type d | head -n1)
  [[ -z "$srcdir" ]] && sleep 5 && continue

  log_line "Processing $srcdir"

  mount_iso "$srcdir/*.iso" || { move_dir_fail "$srcdir" "1.rip.failed"; continue; }

  get_latest_file_time "$MOUNT_POINT" > "$srcdir/latest_timestamp.txt"
  get_tree_listing "$MOUNT_POINT" "$srcdir/tree.txt"

  unmount_iso_and_cleanup "$MOUNT_POINT"

  compress_iso "$srcdir/*.iso" "$srcdir"

  move_dir_success "$srcdir" "2.zip"
done

