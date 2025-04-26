#!/usr/bin/env bash

compress_iso() {
  local iso_path="$1"
  local output_dir="$2"

  local iso_base
  iso_base="$(basename "$iso_path")"
  local tmpfile="${output_dir}/${iso_base}.xz~"
  local finalfile="${output_dir}/${iso_base}.xz"

  xz -v -9e --threads=0 -c "$iso_path" > "$tmpfile"
  mv "$tmpfile" "$finalfile"
}
