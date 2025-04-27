upload_directory() {
  local work="$1"
  local item_name
  item_name="$(basename "$work")"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$work" -type f ! -path "*/.meta/*" -print0)

  if [[ ${#files[@]} -eq 0 ]]; then
    log_error "⚠️ No files to upload in $work"
    return 1
  fi

  local meta_args=()
  meta_get_args "$work" meta_args
  
  ia upload "$item_name" "${files[@]}" "${meta_args[@]}" || return 1
}
