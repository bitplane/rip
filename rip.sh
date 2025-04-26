#!/usr/bin/env bash

DRIVE=/dev/sr0
TODO_DIR=todo

# get_volume_label <iso>
get_volume_label() {
  isoinfo -d -i "$1" 2>/dev/null | grep "^Volume id:" | sed 's/Volume id:[ ]*//;s/ /_/g' || echo ""
}

# process_iso <iso> <basename>
process_iso() {
  local iso="$1"
  local base="$2"
  local mp
  mp=$(mktemp -d)

  echo "→ Trying to mount $iso with fuseiso…"
  if fuseiso "$iso" "$mp"; then
    echo "✓ Mounted via fuseiso"
  else
    echo "❌ ERROR: fuseiso failed. Skipping."
    rmdir "$mp"
    rm -f -- "$iso"
    return
  fi

  mkdir -p "$TODO_DIR"
  local treefile="${TODO_DIR}/${base}.txt"
  pushd "$mp" >/dev/null
  tree -D --timefmt=%Y-%m-%d --du -h -n . > "$OLDPWD/$treefile"
  popd >/dev/null
  echo "✓ File listing saved to $treefile"

  # find newest file timestamp
  local latest_ts
  latest_ts=$(find "$mp" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f1)
  if [[ -z "$latest_ts" ]]; then
    echo "⚠️  No files found in ISO — using current time."
    latest_ts=$(date +%s)
  fi
  echo "→ Latest file in ISO is at $(date -d "@${latest_ts%.*}" '+%Y-%m-%d %H:%M:%S')"

  echo "→ Unmounting…"
  fusermount -u "$mp" || echo "⚠️  fusermount failed (already unmounted?)"
  rmdir "$mp"

  # Prepend date to base
  local prefix
  prefix=$(date -d "@${latest_ts%.*}" '+%Y_%m_%d')
  local final_iso="${TODO_DIR}/${prefix}_${base}.iso"
  local final_xz="${final_iso}.xz"
  local final_tmp="${final_xz}~"
  local final_txt="${final_iso}.txt"

  # Move ISO before compression
  mv -- "$iso" "$final_iso"

  # Compress ISO safely
  if command -v xz &>/dev/null; then
    echo "→ Compressing $final_iso to $final_xz…"
    if xz -v -9e --threads=0 -c "$final_iso" > "$final_tmp"; then
      mv -- "$final_tmp" "$final_xz"
      echo "✓ Compressed to ${final_xz}"
      rm -- "$final_iso"
    else
      echo "❌ Compression failed. Cleaning up."
      rm -f -- "$final_tmp" "$final_iso" "$final_txt"
    fi
  else
    echo "⚠️  xz not found; skipping compression."
  fi
}

# sanity checks
for cmd in fuseiso fusermount dd eject xz tree isoinfo; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not installed. Aborting." >&2
    exit 1
  fi
done

while true; do
  echo "Insert disc and press ENTER when ready (or Ctrl+C to quit)"
  read

  echo "→ Reading volume label from $DRIVE…"
  volume_label=$(isoinfo -d -i "$DRIVE" 2>/dev/null | grep "^Volume id:" | sed 's/Volume id:[ ]*//;s/ /_/g' || echo "")
  if [[ -z "$volume_label" ]]; then
    echo "⚠️  No volume label found."
    volume_label="UNKNOWN"
  fi
  echo "📀 Disc label detected: $volume_label"

  read -p "Enter base name for this ISO (ENTER to use '$volume_label'): " name
  if [[ -z "$name" ]]; then
    name="$volume_label"
  fi

  iso="$(date +%s).iso"  # temp name first
  echo "→ Imaging $DRIVE → $iso…"
  dd if="$DRIVE" of="$iso" bs=2048 status=progress conv=noerror,sync || {
    echo "❌ dd failed. Skipping."
    rm -f -- "$iso"
    continue
  }

  echo "→ Ejecting tray…"
  eject "$DRIVE" || echo "⚠️  Eject failed (maybe manual eject needed?)"

  process_iso "$iso" "$name"

  echo
  echo "done!"
  echo
done
