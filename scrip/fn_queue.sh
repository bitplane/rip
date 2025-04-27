#!/usr/bin/env bash

count_dirs() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l
}


sleep_until_dirs() {
  local dir="$1"
  local srcdir
  while true; do
    srcdir=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
    if [[ -n "$srcdir" ]]; then
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

  mv "$srcdir" "$dest"
}

move_dir_fail() {
  local srcdir="$1"
  local faildir="$2"

  local dest="$faildir/$(basename "$srcdir")"

  if [[ -d "$dest" ]]; then
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    dest="${faildir}/$(basename "$srcdir")_${ts}"
  fi

  mv "$srcdir" "$dest"
}
