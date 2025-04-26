#!/usr/bin/env bash

source "$(dirname "$0")/fn_drive.sh"
source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"
source "$(dirname "$0")/fn_mount.sh"
source "$(dirname "$0")/fn_fileinfo.sh"

BASE_DIR="$(dirname "$(dirname "$0")")"
DEVICE="/dev/sr0"

generate_metadata() {
  local tmpdir="$1"
  local name="$2"

  mount_iso "$tmpdir/$name.iso" || return 1

  get_tree_listing "$MOUNT_POINT" "$tmpdir/tree.txt" || { unmount_iso_and_cleanup; return 1; }
  get_latest_file_time "$MOUNT_POINT" > "$tmpdir/.date" || { unmount_iso_and_cleanup; return 1; }
  head -n 500 "$tmpdir/tree.txt" > "$tmpdir/.info" || { unmount_iso_and_cleanup; return 1; }

  unmount_iso_and_cleanup
}

while true; do
  wait_for_disc "$DEVICE" || continue
  log_line "Disc detected in $DEVICE"

  name=$(get_disc_name "$DEVICE")
  tmpdir="$BASE_DIR/1.rip/$name"
  mkdir -p "$tmpdir"

  log_line "Starting ddrescue for $name"

  if ! create_image "$DEVICE" "$tmpdir/$name.iso" "$tmpdir/$name.ddrescue.log"; then
    log_line "❌ ddrescue failed for $name"
    move_dir_fail "$tmpdir" "$BASE_DIR/1.rip.failed"
    eject_disc "$DEVICE"
    continue
  fi

  log_line "✓ ddrescue completed for $name"

  if ! generate_metadata "$tmpdir" "$name"; then
    log_line "❌ Metadata generation failed for $name"
    move_dir_fail "$tmpdir" "$BASE_DIR/1.rip.failed"
    eject_disc "$DEVICE"
    continue
  fi

  eject_disc "$DEVICE"
  log_line "✓ Disc $name processed successfully"
done
