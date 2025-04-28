upload_directory() {
  local work="$1"
  local item_name
  item_name="$(basename "$work")"

  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$work" -type f ! -path "*/.*" -print0)

  if [[ ${#files[@]} -eq 0 ]]; then
    log_error "⚠️ No files to upload in $work"
    return 1
  fi

  local meta_args=()
  meta_get_args "$work" meta_args
  
  local batch_size=50
  local batch=()
  local count=0
  
  find "$work" -type f ! -path "*/.*" -print0 | while IFS= read -r -d '' file; do
    batch+=("$file")
    ((count++))
    
    # When batch is full, upload it
    if [[ $count -eq $batch_size ]]; then
      ia upload "$item_name" "${batch[@]}" "${meta_args[@]}" || return 1
      batch=()
      count=0
    fi
  done || return 1 # shubshell breaks the first return
  
  # Upload any remaining files
  if [[ ${#batch[@]} -gt 0 ]]; then
    ia upload "$item_name" "${batch[@]}" "${meta_args[@]}" || return 1
  fi

}
