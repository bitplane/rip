#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$BASE_DIR/scrip/libs.sh"

# Run INSIDE the ISO mount, with $MOUNT_POINT set and with set -e
generate_metadata() {
  local work="$1"
  fs_tree "." >> "$work"/tree.txt

  local name
  date=$(fs_last_update "$MOUNT_POINT")
  title="$date $(echo $(basename "$work") | tr '_' ' ')"
  echo "$title"                           |  meta_add title       "$work"
  echo software                           |  meta_add mediatype   "$work"
  echo "$date"                            |  meta_add date        "$work"
  head -n 500 "$work/tree.txt"            |  meta_add description "$work"
  
  fs_extract_icon "." "$work"
}

while true; do
  work=$(queue_wait "$BASE_DIR/2.snip")
  name=$(basename "$work")
  log_info "👀 Extracting metadata for $name"

  if ! iso_run_inside "$work/$name.iso" generate_metadata "$work"; then
    log_error "❌ Metadata generation failed for $name"
    queue_fail "$work"
    continue
  fi

  queue_success "$work"
done
