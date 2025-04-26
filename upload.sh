#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

TODO_DIR=todo
DONE_DIR=done

# Check for IA CLI
if ! command -v ia &>/dev/null; then
  echo "ERROR: 'ia' CLI not found. Install with 'pip install internetarchive' and run 'ia configure' first." >&2
  exit 1
fi

mkdir -p "$DONE_DIR"

while true; do
  # grab the first .iso.xz in TODO_DIR
  files=("$TODO_DIR"/*.iso.xz)
  if (( ${#files[@]} == 0 )); then
    echo "✅ All done – no more .iso.xz in $TODO_DIR"
    break
  fi

  file="${files[0]}"
  filename=$(basename "$file")
  base="${filename%.iso.xz}"
  date="${base:0:10}"
  name_part="${base:11}"
  item_id="${date}_${name_part}"

  echo "→ Uploading '$filename' as item '$item_id'…"
  ia upload "$item_id" "$file" \
    --metadata="title:${name_part}" \
    --metadata="mediatype:software"

  if [[ $? -eq 0 ]]; then
    mv -- "$file" "$DONE_DIR/"
    echo "✓ Moved to $DONE_DIR/$filename"
  else
    echo "⚠️  Upload failed for $filename; stopping."
    exit 1
  fi

  echo
done
