#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$BASE_DIR/scrip/libs.sh"

# Run INSIDE the ISO mount, with $MOUNT_POINT set and with set -e
generate_metadata() {
  local work="$1"
  fs_tree "." >> "$work"/tree.txt

  local name
  if [[ -z "$MOUNT_POINT" ]]; then
    log_error "MOUNT_POINT is not set"
    return 1
  fi
  date=$(fs_last_update "$MOUNT_POINT")
  title="$date $(echo $(basename "$work") | tr '_' ' ')"
  echo "$title"                           |  meta_set title       0 "$work"
  echo software                           |  meta_set mediatype   0 "$work"
  echo "$date"                            |  meta_set date        0 "$work"
  head -n 500 "$work/tree.txt"            |  meta_set description 0 "$work"
  
  fs_extract_icon "." "$work"             || true
}

while true; do
  work=$(queue_wait "$BASE_DIR/2.snip")
  name=$(basename "$work")
  log_info "👀 Extracting metadata for $name"

  if ! fs_run_in "$work/$name.iso" generate_metadata "$work"; then
    log_error "❌ Metadata generation failed for $name"
    queue_fail "$work"
    continue
  fi

  queue_success "$work"
done
