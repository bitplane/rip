#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$BASE_DIR/scrip/libs.sh"

# Run INSIDE the ISO mount, with $MOUNT_POINT set and with set -e
generate_metadata() {
  local work="$1"
  fs_tree "$MOUNT_POINT" >> "$work"/tree.txt

  local name
  date=$(fs_last_update "$MOUNT_POINT")
  title="$date $(echo $(basename "$work") | tr '_' ' ')"
  echo "$title"                           |  meta_add "$work" title
  echo "software"                         |  meta_add "$work" mediatype
  echo "$date"                            |  meta_add "$work" date
  head -n 500 "$work/tree.txt"            |  meta_add "$work" description
  echo "https://github.com/bitplane/rip"  |  meta_add . source
}

while true; do
  work=$(queue_wait "$BASE_DIR/2.snip")
  name=$(basename "$work")
  log_info "👀 Extracting metadata for $name"

  if ! mount_and_run "$work/$name.iso" generate_metadata "$work"; then
    log_error "❌ Metadata generation failed for $name"
    queue_fail "$work"
    continue
  fi

  queue_success "$work"
done
