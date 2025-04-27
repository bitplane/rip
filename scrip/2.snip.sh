#!/usr/bin/env bash
source "$(dirname "$0")/fn_mount.sh"
source "$(dirname "$0")/fn_fileinfo.sh"
source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Run INSIDE the ISO mount, with $MOUNT_POINT set
generate_metadata() {
  local outdir="$1"
  get_tree_listing   "$MOUNT_POINT" "$outdir/tree.txt"
  get_latest_file_time "$MOUNT_POINT" > "$outdir/.date"
  head -n 500 "$outdir/tree.txt" > "$outdir/.info"
}

while true; do
  srcdir=$(sleep_until_dirs "$BASE_DIR/2.snip")
  name=$(basename "$srcdir")
  log_line "Stripping metadata for $name"

  if ! mount_and_run "$srcdir/$name.iso" generate_metadata "$srcdir"; then
    log_line "❌ Metadata generation failed for $name"
    move_dir_fail "$srcdir" "$BASE_DIR/2.strip.failed"
    continue
  fi

  move_dir_success "$srcdir" "$BASE_DIR/3.zip"
  log_line "✓ Metadata stripped for $name"
done
