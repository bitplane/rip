upload_directory() {
  local srcdir="$1"
  local item_name
  item_name="$(basename "$srcdir")"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$srcdir" -maxdepth 1 -type f ! -name '.*' -print0)

  if [[ ${#files[@]} -eq 0 ]]; then
    log_line "⚠️ No files to upload in $srcdir"
    return 1
  fi

  local date=""
  local description=""

  [[ -f "$srcdir/.date" ]] && date=$(cat "$srcdir/.date")
  [[ -f "$srcdir/.info" ]] && description=$(cat "$srcdir/.info")

  ia upload "$item_name" "${files[@]}" \
    --metadata="title:${item_name}" \
    --metadata="mediatype:software" \
    --metadata="date:${date}" \
    --metadata="description:${description}" || return 1
}
