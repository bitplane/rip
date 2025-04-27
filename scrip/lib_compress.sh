compress_iso() {
  local srcdir="$1"

  local iso
  iso=$(find "$srcdir" -maxdepth 1 -name '*.iso' | head -n1)
  if [[ -z "$iso" ]]; then
    log_line "❌ No ISO found in $srcdir"
    return 1
  fi

  local iso_base
  iso_base="$(basename "$iso")"
  local tmpfile="${srcdir}/${iso_base}.xz~"
  local finalfile="${srcdir}/${iso_base}.xz"

  xz -v -9e --threads=0 -c "$iso" > "$tmpfile" || {
      log_line "❌ Failed to compress $iso"
      return 1
  }
  mv "$tmpfile" "$finalfile" || return 1
  rm "$iso" || return 1
}
