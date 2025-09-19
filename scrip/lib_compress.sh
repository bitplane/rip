compress_bins() {
  local work="$1"
  local failed=0
  
  while IFS= read -r file; do
    local dest="${file}.gz"
    log_info "📦 compressing "$(basename "$file")""
    if ! pigz -9 -n -c "$file" > "$dest"; then
        log_error "❌ failed to compress "$(basename "$file")""
        failed=1
        continue
    fi
    rm -f "$file" || {
        log_error "❌ failed to remove original file "$(basename "$file")""
        failed=1
    }
  done < <(find "$work" -type f \( -name '*.iso' -o -name '*.tar' \))
  
  return $failed
}
