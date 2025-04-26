#!/usr/bin/bash
DRIVE=/dev/sr0
TODO_DIR=todo

# process_iso <path-to-iso>
#   mounts (fuseiso or sudo mount), finds newest file date, unmounts, renames into $TODO_DIR,
#   then xz-compresses and removes the uncompressed ISO
process_iso() {
  local iso="$1"
  local mp use_sudo_mount=false
  mp=$(mktemp -d)

  echo "→ Trying to mount $iso with fuseiso…"
  if fuseiso "$iso" "$mp"; then
    echo "✓ Mounted via fuseiso"
  else
    echo "⚠️  fuseiso failed; falling back to sudo mount loop,ro"
    sudo mount -o loop,ro "$iso" "$mp"
    use_sudo_mount=true
  fi

  # find newest file timestamp
  local latest_ts
  latest_ts=$(find "$mp" -type f -printf '%T@ %p\n' \
                | sort -nr \
                | head -n1 \
                | cut -d' ' -f1)

  echo "→ Latest file in ISO is at $(date -d "@${latest_ts%.*}" '+%Y-%m-%d %H:%M:%S')"

  echo "→ Unmounting…"
  if [ "$use_sudo_mount" = true ]; then
    sudo umount "$mp"
  else
    fusermount -u "$mp"
  fi
  rmdir "$mp"

  # format date prefix
  local prefix base dest
  prefix=$(date -d "@${latest_ts%.*}" '+%Y_%m_%d')
  mkdir -p "$TODO_DIR"
  base=$(basename "$iso")
  dest="${TODO_DIR}/${prefix}_${base}"

  mv -- "$iso" "$dest"
  echo "✓ ISO moved to $dest"

  # compress with xz
  if command -v xz &>/dev/null; then
    echo "→ Compressing $dest with xz -v -9e --threads=0…"
    xz -v -9e --threads=0 "$dest" && echo "✓ Compressed to ${dest}.xz"
  else
    echo "⚠️  xz not found; skipping compression."
  fi
}

# sanity checks
for cmd in fuseiso fusermount dd eject xz; do
  if ! command -v $cmd &>/dev/null; then
    echo "ERROR: '$cmd' is required but not installed. Aborting." >&2
    exit 1
  fi
done

while true; do
  read -p "Enter base name for this ISO (ENTER to quit): " name
  [[ -z $name ]] && echo "All done; exiting." && break

  iso="${name}.iso"
  echo "→ Imaging $DRIVE → $iso…"
  sudo dd if="$DRIVE" of="$iso" bs=2048 status=progress conv=noerror,sync

  echo "→ Ejecting tray…"
  sudo eject "$DRIVE"

  process_iso "$iso"

  echo
  read -p "Insert next CD and press ENTER to continue…" _
done
