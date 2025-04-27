#!/usr/bin/env bash

source "$(dirname "$0")/fn_drive.sh"
source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"

# project root
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="/dev/sr0"

while true; do
  wait_for_disc "$DEVICE" || continue
  log_line "Disc detected in $DEVICE"

  name=$(get_disc_name "$DEVICE")
  tmpdir="$BASE_DIR/1.rip/$name"
  mkdir -p "$tmpdir"

  log_line "Starting ddrescue for $name"
  if ! create_image "$DEVICE" \
        "$tmpdir/$name.iso" \
        "$tmpdir/$name.ddrescue.log"; then
    log_line "❌ ddrescue failed for $name"
    move_dir_fail "$tmpdir" "$BASE_DIR/1.rip.failed"
    eject_disc "$DEVICE"
    continue
  fi

  # Move on to the strip stage
  move_dir_success "$tmpdir" "$BASE_DIR/2.strip"
  eject_disc "$DEVICE"
  log_line "✓ Disc $name ripped successfully"
done
