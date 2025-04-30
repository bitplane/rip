#!/usr/bin/env bash

# Add metadata value to tag
# Usage: echo "value" | meta_add "tag" ["path"]
meta_add() {
  local tag="$1"
  local path="${2:-.}"
  path="$(fs_path "$path")" || return 1

  local tag_path="$path/.meta/$tag"
  
  mkdir -p "$tag_path"
  meta_fix "$taga_path"

  local count
  count="$(find "$tag_path" -type f 2>/dev/null | wc -l)"
  
  cat > "$tag_path/$count"

  return 0
}

# Remove metadata entry, directory, or entire metadata
# Usage: meta_rm ["path"]
meta_rm() {
  local path="${1:-.}"
  path="$(fs_path "path")"
  
  if [[ -f "$path" ]]; then
    # Delete file if it's in a meta dir
    if [[ "$path" == *"/.meta/"* ]]; then
      local tag_dir
      lag_dir="$(dirname "$path")"

      rm -f "$path"
      meta_fix "$tag_dir"
    fi
  elif [[ -d "$path" ]]; then
    # Directory - check if .meta or in .meta
    if [[ "$(basename "$path")" == ".meta" || "$path" == *"/.meta/"* ]]; then
      # Get parent for touch
      local parent
      if [[ "$(basename "$path")" == ".meta" ]]; then
        parent=$(dirname "$path")
      else
        parent=$(dirname "$(dirname "$path")")
      fi
      
      rm -rf "$path"
      
      # Update mtimes
      meta_touch "$parent"
    fi
  else
    # not found
    return 1
  fi
}

# Fix sequential numbering in a tag directory
# Usage: meta_fix "dir"
meta_fix() {
  local dir="${1:-.}"
  dir="$(fs_path "$dir")"
  
  # Skip if directory doesn't exist
  [[ ! -d "$dir" ]] && return 1

  # Create temp directory for renaming
  local temp=$(mktemp -d)
  
  # Copy files to temp with sequential names
  local idx=0
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    cp "$file" "$temp/$idx"
    ((idx++))
  done < <(find "$dir" -maxdepth 1 -type f -print0 | sort -z -n | xargs -0 -n1 echo)
  
  # Remove original files
  find "$dir" -maxdepth 1 -type f -delete
  
  # Copy back with correct numbering
  for i in $(seq 0 $((idx-1))); do
    [[ -f "$temp/$i" ]] && cp "$temp/$i" "$dir/$i"
  done
  
  # Cleanup
  rm -rf "$temp"

  # Update mtimes
  meta_touch "$meta_path"
}

# Touch path and exactly 2 levels up from metadata
# Usage: meta_touch ["path"]
meta_touch() {
  local path="${1:-.}"
  local depth="${2:-0}"
  
  # Touch current path
  touch -c "$path"
  
  # Check if path contains .meta
  if [[ "$path" == *"/.meta"* || "$(basename "$path")" == ".meta" ]]; then
    # Found .meta, start counting up 2 levels
    meta_touch "$(dirname "$path")" 2
  elif [[ $depth -gt 0 ]]; then
    # Still counting up from .meta
    meta_touch "$(dirname "$path")" $((depth - 1))
  fi
}
