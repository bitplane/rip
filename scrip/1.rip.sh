#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$BASE_DIR/scrip/lib_drive.sh"
source "$BASE_DIR/scrip/lib_log.sh"
source "$BASE_DIR/scrip/lib_queue.sh"

DEVICE="${1:-$(get_drives | head -n1)}"


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
    move_dir_fail "$tmpdir"
    eject_disc "$DEVICE"
    continue
  fi

  # Move on to the strip stage
  move_dir_success "$tmpdir" "$BASE_DIR/2.snip"
  eject_disc "$DEVICE"
  log_line "✓ Disc $name ripped successfully"
done
