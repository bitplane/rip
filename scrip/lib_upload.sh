upload_directory() {
  local work="$1"
  local item_name
  item_name="$(basename "$work")"

  (
    local meta_args=()
    meta_get_args "$work" meta_args
 
    cd "$work" || return 1

    local files=()
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(find . -type f ! -path "./.*" -print0 | sort -z)

    if [[ ${#files[@]} -eq 0 ]]; then
      log_error "⚠️ No files to upload in $work"
      return 1
    fi

    local batch_size=50
    local batch=()
    local count=0
    local total=0
  
    for file in "${files[@]}"; do
      batch+=("${file#./}")
      ((count++))
      ((total++))

      if [[ $count -eq $batch_size ]]; then
        ia upload -c --keep-directories --retries=100 --sleep=120 "${meta_args[@]}" "$item_name" -- "${batch[@]}" || return 1
        echo Uploaded "$(du -ch -- "${batch[@]}" | tail -1 | cut -f 1) ($total files in total)"...
        batch=()
        count=0
      fi
    done

    # Upload any remaining files
    if [[ ${#batch[@]} -gt 0 ]]; then
      ia upload -c --keep-directories --retries=100 --sleep=120 "${meta_args[@]}" "$item_name" -- "${batch[@]}" || return 1
    fi
  ) || return 1
}
