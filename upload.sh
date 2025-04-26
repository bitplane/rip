#!/usr/bin/env bash
# No set -e -u -o pipefail; stay alive

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

  # Parse date and name
  raw_date="${base:0:10}"         # e.g. 1997_02_13
  name_part="${base:11}"          # rest of the name
  date="${raw_date//_/-}"         # 1997-02-13
  item_id="${raw_date}_${name_part}" # item ID (still with underscores)
  title="${name_part//_/ }"       # title (spaces instead of underscores)

  # Associated tree listing file
  txtfile="${TODO_DIR}/${base}.txt"

  # Prepare description from the tree listing
  if [[ -f "$txtfile" ]]; then
    description=$(head -c 16384 "$txtfile")
  else
    description="Backup of ISO image ${title}."
  fi

  echo "→ Uploading '$filename' as item '$item_id'…"
  ia upload "$item_id" "$file" "$txtfile" \
    --metadata="title:${title}" \
    --metadata="mediatype:software" \
    --metadata="date:${date}" \
    --metadata="description:${description}"

  if [[ $? -eq 0 ]]; then
    mv -- "$file" "$DONE_DIR/"
    [[ -f "$txtfile" ]] && mv -- "$txtfile" "$DONE_DIR/"
    echo "✓ Moved to $DONE_DIR/"
  else
    echo "⚠️  Upload failed for $filename; stopping."
    exit 1
  fi

  echo
done
