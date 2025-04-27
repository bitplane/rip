count_dirs() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l
}


sleep_until_dirs() {
  local dir="$1"
  local srcdir
  log_line "🔍 watching $dir for work"
  while true; do
    srcdir=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
    if [[ -n "$srcdir" ]]; then
      log_line "📂 found $srcdir"
      echo "$srcdir"
      return 0
    fi
    sleep 5
  done
}

move_dir_success() {
  local srcdir="$1"
  local successdir="$2"

  local dest="$successdir/$(basename "$srcdir")"

  if [[ -d "$dest" ]]; then
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    dest="${successdir}/$(basename "$srcdir")_${ts}"
  fi

  log_line "🎉 moving $srcdir to $dest"
  mv "$srcdir" "$dest" || return 1
}

move_dir_fail() {
  local srcdir="$1"
  local faildir=$(dirname "$srcdir").skip
  local dest="$faildir/$(basename "$srcdir")"

  if [[ -d "$dest" ]]; then
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    dest="${faildir}/$(basename "$srcdir")_${ts}"
  fi
  log_line "💩 moving $srcdir to $dest"
  mv "$srcdir" "$dest"
}
