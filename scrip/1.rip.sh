#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scrip/libs.sh"

DEVICE="${1:-$(drive_list | head -n1)}"

while true; do
  drive_eject  "$DEVICE"
  drive_wait   "$DEVICE" || continue

  name=$(iso_get_name "$DEVICE")
  work="$BASE_DIR/1.rip/$name"

  mkdir -p "$work"
  meta_add "scanner" "$work" <<< "rip (https://github.com/bitplane/rip)"

  log_info "⬇️ ripping $name"
  if ! drive_dump "$DEVICE" \
        "$work/$name.iso" \
        "$work/$name.ddrescue.log"; then

    log_error     "❌ ddrescue failed for $name"
    queue_fail    "$work"
    continue
  fi
  queue_success "$work"

done
