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
  local prefix base tmp_dest final_dest
  prefix=$(date -d "@${latest_ts%.*}" '+%Y_%m_%d')
  mkdir -p "$TODO_DIR"
  base=$(basename "$iso")
  tmp_dest="${prefix}_${base}"
  final_dest="${TODO_DIR}/${tmp_dest}.xz"

  # compress with xz
  if command -v xz &>/dev/null; then
    echo "→ Compressing $iso to temporary file with xz -v -9e --threads=0…"
    xz -v -9e --threads=0 -c "$iso" > "${tmp_dest}.xz"
    echo "✓ Compressed to ${tmp_dest}.xz"

    # move compressed file into TODO_DIR
    mv -- "${tmp_dest}.xz" "$final_dest"
    echo "✓ Moved compressed file to $final_dest"
  else
    echo "⚠️  xz not found; skipping compression."
    exit 1
  fi

  # clean up uncompressed ISO
  rm -- "$iso"
}
