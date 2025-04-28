# Add a metadata value, supporting multiple values per key
meta_add() {
  local item="$1"
  local key="$2"
  local path="$item/.meta/$key"
  local count
  
  mkdir -p "$path"
  count=$(find "$path" -type f 2>/dev/null | wc -l)
  cat > "$path/$count"
}

meta_get() {
  local item="$1"
  local key="$2"
  find "$item/.meta/$key" -type f -print0 | xargs -0 cat 2>/dev/null || true
}

meta_get_args() {
  local item="$1"
  local -n out_array=$2  # Nameref to caller's array
  
  # Reset the array
  out_array=()
  
  # Skip if no metadata directory
  [[ -d "$item/.meta" ]] || return 0
  
  # Process each metadata key
  for key_dir in "$item/.meta"/*; do
    [[ -d "$key_dir" ]] || continue
    
    local key
    key=$(basename "$key_dir")
    
    # Process each value file for this key
    for value_file in "$key_dir"/*; do
      [[ -f "$value_file" ]] || continue
      out_array+=("--metadata=$key:$(cat "$value_file")")
    done
  done
}
