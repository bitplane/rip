compress_iso() {
  local work="$1"

  local iso
  iso=$(find "$work" -maxdepth 1 -name '*.iso' | head -n1)
  if [[ -z "$iso" ]]; then
    log_info "❌ No ISO found in $work" >&2
    return 1
  fi

  local iso_base
  iso_base="$(basename "$iso")"
  local dest="$work"/"$iso_base".xz

  xz -v -9e --threads=0 -c "$iso" > "$dest" || {
      log_error "❌ Failed to compress $iso" >&2
      return 1
  }
  rm "$iso" || return 1
}
