compress_bins() {
  local work="$1"
  find "$work" -type f \( -name '*.iso' -o -name '*.tar' \) | while IFS= read -r file; do
    local dest="${file}.xz"
    log_info "📦 compressing "$(basename "$file")""
    if ! xz -v -9e --threads=0 -c "$file" > "$dest"; then
        log_error "❌ failed to compress "$(basename "$file")""
        return 1
    fi
    rm -f "$file" || return 1
  done
}
