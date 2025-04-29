
fs_last_update() {
  local mount_point="$1"
  latest=$(
    find "$mount_point" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -nr | \
        head -n1 | \
        cut -d' ' -f1 | \
        cut -d'.' -f1)
  date -d "@$latest" +"%Y-%m-%d"
}

fs_tree() {
  local mount_point="$1"

  pushd "$mount_point" >/dev/null || return 1
  tree -D --timefmt=%Y-%m-%d --du -h -n .
  popd >/dev/null || return 1
}

fs_extract_icon() {
  local src="$1"
  local dest="$2"

  # Find autorun.inf (case insensitive)
  local autorun
  autorun=$(find "$src" -iname 'autorun.inf' -print -quit -maxdepth 1)

  if [[ -z "$autorun" ]]; then
    return 0
  fi

  # Extract icon path
  local icon_file
  icon_file=$(grep -i '^icon=.*\.ico$' "$autorun" | head -n1 | sed -E 's/^[Ii][Cc][Oo][Nn]=//i')

  if [[ -z "$icon_file" ]]; then
    return 0
  fi

  # Clean possible leading/trailing spaces
  icon_file="$(echo "$icon_file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  # Full path to the icon
  local full_icon_path="$src/$icon_file"

  if [[ ! -f "$full_icon_path" ]]; then
    log_error "❌ Couldn't find ICO file at $icon_file" >&2
    return 0
  fi

  # Convert .ico to .png
  if command -v convert > /dev/null; then
    log_info "🖼️ converting icon to $dest/icon.png"
    convert "$full_icon_path" "$dest"/icon.png
  else
    log_error "❌ 'convert' command not found. Install ImageMagick to enable icon conversion." >&2
    cp "$full_icon_path" "$dest"
    return 0
  fi

  return 0
}

