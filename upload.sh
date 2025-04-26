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
  files=("$TODO_DIR"/*.iso.xz)
  if (( ${#files[@]} == 0 )); then
    echo "✅ All done – no more .iso.xz in $TODO_DIR"
    break
  fi

  file="${files[0]}"
  filename=$(basename "$file")
  base="${filename%.iso.xz}"

  # Split out the date (first 10 characters) and the rest
  raw_date="${base:0:10}"    # e.g., 1997_02_13
  name_part="${base:11}"     # e.g., dk_xp42_eyewitness_encylopedia_of_science_2.0

  # Convert date underscores to dashes
  date="${raw_date//_/-}"    # 1997-02-13

  item_id="${raw_date}_${name_part}"  # Keep item_id with underscores for IA ID
  title="${name_part//_/ }"            # optional: make the title nicer by replacing underscores with spaces

  echo "→ Uploading '$filename' as item '$item_id'…"
  ia upload "$item_id" "$file" \
    --metadata="title:${title}" \
    --metadata="mediatype:software" \
    --metadata="date:${date}"

  if [[ $? -eq 0 ]]; then
    mv -- "$file" "$DONE_DIR/"
    echo "✓ Moved to $DONE_DIR/$filename"
  else
    echo "⚠️  Upload failed for $filename; stopping."
    exit 1
  fi

  echo
done
