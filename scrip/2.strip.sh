#!/usr/bin/env bash

source "$(dirname "$0")/fn_mount.sh"
source "$(dirname "$0")/fn_fileinfo.sh"
source "$(dirname "$0")/fn_log.sh"
source "$(dirname "$0")/fn_queue.sh"

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# This runs *inside* the mounted ISO
generate_metadata() {
  local outdir="$1"

  get_tree_listing "$MOUNT_POINT" "$outdir/tree.txt"
  get_latest_file_time "$MOUNT_POINT" > "$outdir/.date"
  head -n 500 "$outdir/tree.txt"   > "$outdir/.info"
}

process_strip() {
  local srcdir="$1"
  local name
  name=$(basename "$srcdir")

  # mount_and_run will trap+unmount for us
  mount_and_run "$srcdir/$name.iso" \
                generate_metadata \
                "$srcdir"
}

while true; do
  srcdir=$(sleep_until_dirs "$BASE_DIR/2.strip")

  log_line "Stripping metadata for $(basename "$srcdir")"
  if ! process_strip "$srcdir"; then
    log_line "❌ Metadata strip failed for $(basename "$srcdir")"
    move_dir_fail "$srcdir" "$BASE_DIR/2.strip.failed"
    continue
  fi

  move_dir_success "$srcdir" "$BASE_DIR/3.zip"
  log_line "✓ Metadata stripped for $(basename "$srcdir")"
done
