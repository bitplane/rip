#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$BASE_DIR/scrip/libs.sh"

# Run INSIDE the ISO mount, with $MOUNT_POINT set and with set -e
generate_metadata() {
  local work="$1"
  fs_tree "." >> "$work"/tree.txt

  local name
  date=$(fs_last_update ".")
  title="$date $(echo $(basename "$work") | tr '_' ' ')"
  echo "$title"                           |  meta_set title       0 "$work"
  echo software                           |  meta_set mediatype   0 "$work"
  echo "$date"                            |  meta_set date        0 "$work"
  head -n 500 "$work/tree.txt"            |  meta_set description 0 "$work"
  
  fs_extract_icon "." "$work"             || true
}

# Generate metadata for IMG files using mtools
generate_img_metadata() {
  local work="$1"
  local image_file="$2"
  
  # Create a temporary mount point to mimic the mounted filesystem approach
  local tmp_mount=$(mktemp -d)
  
  # Extract all files to temp directory with preserved timestamps
  MTOOLS_SKIP_CHECK=1 mcopy -sm -i "$image_file" :: "$tmp_mount/" 2>/dev/null || true
  
  # Use existing fs_last_update function on extracted files (now with correct timestamps)
  date=$(fs_last_update "$tmp_mount")
  
  # Use mtools to create tree listing for description  
  MTOOLS_SKIP_CHECK=1 mdir -/ -i "$image_file" :: > "$work"/tree.txt 2>/dev/null || echo "No files found" > "$work"/tree.txt
  
  # Clean up temp directory
  rm -rf "$tmp_mount"
  
  title="$date $(echo $(basename "$work") | tr '_' ' ')"
  echo "$title"                           |  meta_set title       0 "$work"
  echo software                           |  meta_set mediatype   0 "$work"  
  echo "$date"                            |  meta_set date        0 "$work"
  head -n 500 "$work/tree.txt"            |  meta_set description 0 "$work"
  
  return 0
}

while true; do
  work=$(queue_wait "$BASE_DIR/2.snip")
  name=$(basename "$work")
  log_info "👀 Extracting metadata for $name"

  # Find the image file (could be .iso or .img)
  image_file=""
  if [ -f "$work/$name.iso" ]; then
    image_file="$work/$name.iso"
  elif [ -f "$work/$name.img" ]; then
    image_file="$work/$name.img"
  else
    log_error "❌ No image file found for $name"
    queue_fail "$work"
    continue
  fi

  # Handle different image types
  if [[ "$image_file" == *.img ]]; then
    # Use mtools for IMG files (FAT filesystems)
    if ! generate_img_metadata "$work" "$image_file"; then
      log_error "❌ Metadata generation failed for $name"
      queue_fail "$work"
      continue
    fi
  else
    # Use fs_run_in for ISO files
    if ! fs_run_in "$image_file" generate_metadata "$work"; then
      log_error "❌ Metadata generation failed for $name"
      queue_fail "$work"
      continue
    fi
  fi

  queue_success "$work"
done
