#!/usr/bin/env bash

#
# Metadata handling functions.
# Metadata is stored in the work item's dir under the .meta dir
# like so: ./item/.meta/tag/0
#

# Add metadata value to tag
# Usage: echo "value" | meta_add "tag" ["path"]
meta_add() {
    local tag="$1" path="${2:-.}"
    local count
    meta_set "$tag" "$(meta_count "$tag" "$path")" "$path"
}

# Set metadata at a specific tag index
# Usage: echo "value" | meta_set "tag" ["idx"] ["path"]
meta_set() {
    local tag="$1" idx="$2" path="${3:-.}"
    # dir must exist, index must be numeric
    path="$(fs_path "$path")" || return 1
    [[ -z "$idx" ]] && { count=$(meta_count "$tag" "$path"); idx=$((count - 1)); }
    [[ "$idx" =~ ^[0-9]+$ ]] || return 1

    local tag_path="$path/.meta/$tag" current=0
    mkdir -p "$tag_path"
    # ensure consistency
    meta_fix "$tag_path"
    current=$(meta_count "$tag" "$path")
    seq "$current" "$idx" | xargs -I{} touch "$tag_path/{}"

    # update the data
    cat > "$tag_path/$idx"
    meta_touch "$tag_path"

    # fire hook if there is one
    [[ "$(type -t meta_hook_$tag)" == "function" ]] && \
        "meta_hook_$tag" "$path" < "$tag_path/$idx"
}

# Fix sequential numbering in a tag directory
# Usage: meta_fix [path]
meta_fix() {
    local path="${1:-.}"
    path="$(fs_path "$path")"
  
    # Skip if directory doesn't exist
    [[ ! -d "$path" ]] && return 1

    # Create temp directory for renaming
    local temp=$(mktemp -d)
  
    # Copy files to temp with sequential names
    local idx=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        mv "$file" "$temp/$idx"
        ((idx++))
    done < <(find "$path" -maxdepth 1 -type f -print0 | sort -z -n | xargs -0 -n1 echo)
  
    # Remove original files
    find "$path" -maxdepth 1 -type f -delete
  
    # Copy back with correct numbering
    for i in $(seq 0 $((idx-1))); do
        [[ -f "$temp/$i" ]] && mv "$temp/$i" "$path/$i"
    done
  
    # Cleanup
    rm -rf "$temp"

    # Update mtimes
    meta_touch "$path"
}

# Touch path and exactly 2 levels up from metadata
# Makes it possible to know when something has changed, including dirs of dirs
# Usage: meta_touch ["path"]
meta_touch() {
    local path="${1:-.}" depth="${2:-0}"
    path="$(fs_path "$path")"
  
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

# Possibly temporary until we have an export for IA
#
meta_get_args() {
    local item="$1"
    local -n out_array=$2  # Nameref to caller's array

    # Reset the array
    out_array=()

    # Skip if no metadata directory
    [[ -d "$item/.meta" ]] || return 0

    # Process each metadata tag
    for tag in $(meta_tags "$1"); do
        local count=$(meta_count "$tag" "$item")
        for idx in $(seq 0 $((count - 1))); do
            out_array+=("--metadata=$tag:$(meta_get "$tag" "$idx" "$item")")
        done
    done
}

# Returns metadata. Can use globs in tag name and index
# Usage: meta_get [tag] [idx] [path]
meta_get() {
    local tag="${1:-*}" idx="${2:-*}" path="${3:-.}"
    local base="$path/.meta"
    # default to latest value
    [[ -z "$idx" ]] && { count=$(meta_count "$tag" "$path"); idx=$((count - 1)); }

    ( # subshell because shopt
        shopt -s nullglob
        for tagdir in "$base"/$tag; do
            for file in "$tagdir"/$idx; do
                cat "$file"
            done
        done
    )
}

# Lists metadata tags
# Usage: meta_tags [path]
meta_tags() {
    find "${1:-.}/.meta" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null
}

# Removes tag(s) or all metadata. Wildcards accepted, use with care.
# Usage: meta_rm [tag] [idx] [path]
meta_rm() {
  local tag="${1:-*}" idx="${2:-*}" path="${3:-.}"
  local basedir="$path/.meta"

  ( # subshell to contain nullglob
    shopt -s nullglob
    for tagdir in "$base"/$tag; do
      local removed=false
      for file in "$tagdir"/$idx; do
        rm -f "$file" && removed=true
      done
      if "$removed" && [[ -d "$tagdir" ]]; then
        meta_fix "$tagdir"
        [[ -z "$(ls -A "$tagdir")" ]] && rmdir "$tagdir"
      fi
    done
    [[ -d "$base" && -z "$(ls -A "$base")" ]] && rmdir "$base" && meta_touch "$path"
  )
}

# Gets the count of tags or entries for a given dir's metadata
# Usage: meta_count [tag] [path]
meta_count() {
    local tag="$1" path="${2:-.}"
    find "$path/.meta/$tag" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l
}
