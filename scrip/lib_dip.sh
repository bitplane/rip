#!/usr/bin/env bash
# dip.sh - Minimal metadata editor for archive.org items
# Part of the "rip" tool suite

# Find the base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
source "$BASE_DIR/scrip/libs.sh"

# Global vars (minimized)
_DIP_DIR="$BASE_DIR"
_DIP_CURSOR=0
_DIP_VIEW="browse"  # browse, metadata, files
_DIP_ITEM=""
_DIP_TAG=""
_DIP_ENTRIES=()
_DIP_CACHE_DIR="/tmp/dip-cache-$$"

# Initialize terminal
_dip_in() {
  # Terminal setup
  tput smcup
  tput civis
  stty -echo raw
  
  # Cache dir
  mkdir -p "$_DIP_CACHE_DIR"
  
  # Set trap
  trap _dip_out EXIT INT TERM
}

# Cleanup and exit
_dip_out() {
  # Restore terminal
  tput rmcup
  tput cnorm
  stty echo -raw
  
  # Clean up cache
  rm -rf "$_DIP_CACHE_DIR" 2>/dev/null
  
  exit 0
}

# Get cached directory listing
_dip_get_listing() {
  local dir="$1"
  local cache_key=$(stat -c "%i_%Y" "$dir" 2>/dev/null || echo "none")
  local cache_file="$_DIP_CACHE_DIR/listing_$cache_key"
  
  # Use cache if exists
  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
    return
  fi
  
  # Generate and cache listing
  find "$dir" -maxdepth 1 -mindepth 1 -type d -not -path "*/\.*" -printf "%f\n" | sort > "$cache_file"
  cat "$cache_file"
}

# Get emoji for directory
_dip_get_emoji() {
  local dir="$1"
  local base=$(basename "$dir")
  local emoji=" "
  
  # Skip dirs get ❌
  if [[ $base =~ \.skip$ ]]; then
    emoji="❌"
  # Stage directory or in stage
  elif [[ $base =~ ^[1-5]\. ]]; then
    local num=${base:0:1}
    local emojis=("💽" "👀" "📦" "🔝" "🍻")
    emoji="${emojis[$((num-1))]}"
  elif [[ $(dirname "$dir") =~ ^.*/[1-5]\. ]]; then
    local parent=$(basename "$(dirname "$dir")")
    local num=${parent:0:1}
    local emojis=("💽" "👀" "📦" "🔝" "🍻")
    emoji="${emojis[$((num-1))]}"
  fi
  
  echo "$emoji"
}

# List directory entries with optional smart caching
_dip_list_entries() {
  # Reset entries array
  _DIP_ENTRIES=()
  
  # Add parent directory if not at BASE_DIR
  [[ "$_DIP_DIR" != "$BASE_DIR" ]] && _DIP_ENTRIES+=("..")
  
  # Add directories (using cache if available)
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    _DIP_ENTRIES+=("$entry")
  done < <(_dip_get_listing "$_DIP_DIR")
  
  # Adjust cursor position if needed
  [[ $_DIP_CURSOR -ge ${#_DIP_ENTRIES[@]} ]] && _DIP_CURSOR=$((${#_DIP_ENTRIES[@]} - 1))
  [[ $_DIP_CURSOR -lt 0 ]] && _DIP_CURSOR=0
}

# List metadata tags with caching
_dip_list_tags() {
  # Reset entries array
  _DIP_ENTRIES=()
  
  # Get cache key based on metadata directory mtime
  local meta_dir="$_DIP_DIR/$_DIP_ITEM/.meta"
  local cache_key=$(stat -c "%i_%Y" "$meta_dir" 2>/dev/null || echo "none")
  local cache_file="$_DIP_CACHE_DIR/tags_$cache_key"
  
  # Use cache if exists
  if [[ -f "$cache_file" ]]; then
    mapfile -t _DIP_ENTRIES < "$cache_file"
  else
    # Get tags from meta_tags function
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      _DIP_ENTRIES+=("$tag")
    done < <(meta_tags "$_DIP_DIR/$_DIP_ITEM")
    
    # Cache result if entries found
    if [[ ${#_DIP_ENTRIES[@]} -gt 0 ]]; then
      printf "%s\n" "${_DIP_ENTRIES[@]}" > "$cache_file"
    fi
  fi
  
  # Adjust cursor position
  [[ $_DIP_CURSOR -ge ${#_DIP_ENTRIES[@]} ]] && _DIP_CURSOR=$((${#_DIP_ENTRIES[@]} - 1))
  [[ $_DIP_CURSOR -lt 0 ]] && _DIP_CURSOR=0
}

# List tag files with caching
_dip_list_files() {
  # Reset entries array
  _DIP_ENTRIES=()
  
  # Get cache key based on tag directory mtime
  local tag_dir="$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG"
  local cache_key=$(stat -c "%i_%Y" "$tag_dir" 2>/dev/null || echo "none")
  local cache_file="$_DIP_CACHE_DIR/files_$cache_key"
  
  # Use cache if exists
  if [[ -f "$cache_file" ]]; then
    mapfile -t _DIP_ENTRIES < "$cache_file"
  else
    # Get files
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      _DIP_ENTRIES+=("$file")
    done < <(find "$tag_dir" -maxdepth 1 -mindepth 1 -type f -printf "%f\n" 2>/dev/null | sort -n)
    
    # Cache result if entries found
    if [[ ${#_DIP_ENTRIES[@]} -gt 0 ]]; then
      printf "%s\n" "${_DIP_ENTRIES[@]}" > "$cache_file"
    fi
  fi
  
  # Adjust cursor position
  [[ $_DIP_CURSOR -ge ${#_DIP_ENTRIES[@]} ]] && _DIP_CURSOR=$((${#_DIP_ENTRIES[@]} - 1))
  [[ $_DIP_CURSOR -lt 0 ]] && _DIP_CURSOR=0
}

# Display a row with or without highlighting
_dip_row() {
  local selected=$1
  local symbol=$2
  local text=$3
  local details=${4:-""}
  
  if [[ $selected -eq 1 ]]; then
    tput rev; tput bold
    printf " %s %s " "$symbol" "$text"
    
    if [[ -n "$details" ]]; then
      tput sgr0; tput rev; tput setaf 6
      printf "%s" "$details"
    fi
    
    tput sgr0
  else
    printf " %s %s " "$symbol" "$text"
    
    if [[ -n "$details" ]]; then
      tput setaf 6
      printf "%s" "$details"
      tput sgr0
    fi
  fi
  
  printf "\r\n"
}

# Get status bar text for current view
_dip_status_bar() {
  case $_DIP_VIEW in
    browse)
      echo "Arrows: navigate | Return: select | a: add meta | d: delete meta | q: quit"
      ;;
    metadata)
      echo "Arrows: navigate | Return: select | a: add tag | d: delete tag | q: quit"
      ;;
    files)
      echo "Arrows: navigate | Return/e: edit | a: add entry | d: delete | q: quit"
      ;;
  esac
}

# User prompt with y/n
_dip_prompt() {
  local message="$1"
  local default="${2:-N}"
  
  tput cup $(($(tput lines) - 1)) 0
  tput el
  echo -n "$message [$default] "
  
  local answer
  read -r -n 1 answer
  [[ -z "$answer" ]] && answer="$default"
  
  case "$answer" in
    [yY]) return 0 ;;
    *) return 1 ;;
  esac
}

# Draw screen
_dip_draw() {
  local term_height=$(tput lines)
  local visible_rows=$((term_height - 4))
  local temp_output=$(mktemp)
  
  # Header
  tput bold > "$temp_output"
  case $_DIP_VIEW in
    browse)
      printf "Directory: %s\r\n" "$_DIP_DIR" >> "$temp_output"
      ;;
    metadata)
      printf "Metadata for: %s\r\n" "$_DIP_ITEM" >> "$temp_output"
      ;;
    files)
      printf "Tag: %s in %s\r\n" "$_DIP_TAG" "$_DIP_ITEM" >> "$temp_output"
      ;;
  esac
  tput sgr0 >> "$temp_output"
  
  # Divider
  printf "────────────────────────────────────────────────────\r\n" >> "$temp_output"
  
  # Calculate scroll position
  local start_idx=0
  if [[ ${#_DIP_ENTRIES[@]} -gt $visible_rows ]]; then
    local half_view=$((visible_rows / 2))
    
    if [[ $_DIP_CURSOR -ge $half_view ]]; then
      start_idx=$((_DIP_CURSOR - half_view))
    fi
    
    if [[ $((start_idx + visible_rows)) -gt ${#_DIP_ENTRIES[@]} ]]; then
      start_idx=$((${#_DIP_ENTRIES[@]} - visible_rows))
    fi
  fi
  
  # End index
  local end_idx=$((start_idx + visible_rows))
  [[ $end_idx -gt ${#_DIP_ENTRIES[@]} ]] && end_idx=${#_DIP_ENTRIES[@]}
  
  # Draw entries
  for ((i=start_idx; i<end_idx; i++)); do
    local entry="${_DIP_ENTRIES[$i]}"
    local selected=0
    local symbol=" "
    local details=""
    
    [[ $i -eq $_DIP_CURSOR ]] && selected=1
    
    case $_DIP_VIEW in
      browse)
        [[ "$entry" != ".." ]] && symbol=$(_dip_get_emoji "$_DIP_DIR/$entry")
        
        if [[ "$entry" != ".." && -d "$_DIP_DIR/$entry/.meta" ]]; then
          local tags=$(meta_tags "$_DIP_DIR/$entry" | tr '\n' ' ' | head -c 40)
          details="${tags:-(no tags)}"
          
          # Capture the output of _dip_row
          _dip_row $selected "$symbol" "[$entry]" "$details" >> "$temp_output"
        else
          _dip_row $selected "$symbol" "$entry" >> "$temp_output"
        fi
        ;;
      metadata)
        local count=$(meta_count "$entry" "$_DIP_DIR/$_DIP_ITEM")
        
        if [[ $count -gt 0 ]]; then
          local preview=$(meta_get "$entry" "$_DIP_DIR/$_DIP_ITEM" | head -n 1 | head -c 40)
          [[ ${#preview} -gt 39 ]] && preview="${preview:0:37}..."
          details="$preview"
        else
          details="(empty)"
        fi
        
        _dip_row $selected "$symbol" "$entry ($count):" "$details" >> "$temp_output"
        ;;
      files)
        local content=$(cat "$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG/$entry" 2>/dev/null | head -n 1 | head -c 50)
        [[ ${#content} -gt 49 ]] && content="${content:0:47}..."
        
        _dip_row $selected "$symbol" "$entry:" "$content" >> "$temp_output"
        ;;
    esac
  done
  
  # Status bar position
  printf "\033[%d;0H" $((term_height - 1)) >> "$temp_output"
  tput bold >> "$temp_output"
  printf "%s\r\n" "$(_dip_status_bar)" >> "$temp_output"
  tput sgr0 >> "$temp_output"
  
  # Output everything at once
  clear
  cat "$temp_output"
  rm "$temp_output"
}

# Add metadata to item
_dip_add_meta() {
  local item="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  # Skip special entries
  [[ "$item" == ".." ]] && return
  
  # Create metadata dir
  mkdir -p "$_DIP_DIR/$item/.meta"
  meta_touch "$_DIP_DIR/$item/.meta"
}

# Add tag with prompt
_dip_add_tag() {
  # Return to normal terminal mode for input
  tput cnorm
  stty echo -raw
  
  # Prompt for tag name
  tput cup $(($(tput lines) - 1)) 0
  tput el
  echo -n "Enter tag name: "
  read -r tag
  
  # If not empty, create tag and edit first entry
  if [[ -n "$tag" ]]; then
    meta_new "$tag" "$_DIP_DIR/$_DIP_ITEM"
    _dip_list_tags
  fi
  
  # Return to raw mode
  stty -echo raw
  tput civis
}

# Add entry to tag
_dip_add_entry() {
  meta_new "$_DIP_TAG" "$_DIP_DIR/$_DIP_ITEM"
  _dip_list_files
}

# Edit tag entry
_dip_edit_entry() {
  local file="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  meta_edit "$_DIP_TAG" "$file" "$_DIP_DIR/$_DIP_ITEM"
  _dip_list_files
}

# Delete tag entry with confirmation
_dip_delete_entry() {
  local file="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  if _dip_prompt "Delete entry $file? [y/N]" "N"; then
    meta_del_entry "$_DIP_TAG" "$file" "$_DIP_DIR/$_DIP_ITEM"
    _dip_list_files
  fi
}

# Delete metadata tag with confirmation
_dip_delete_tag() {
  local tag="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  if _dip_prompt "Delete tag $tag and ALL entries? [y/N]" "N"; then
    meta_del_tag "$tag" "$_DIP_DIR/$_DIP_ITEM"
    _dip_list_tags
  fi
}

# Delete all metadata with confirmation
_dip_delete_meta() {
  local item="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  # Skip special entries
  [[ "$item" == ".." ]] && return
  
  if _dip_prompt "Delete ALL metadata for $item? [y/N]" "N"; then
    meta_rm "$_DIP_DIR/$item/.meta"
    _dip_list_entries
  fi
}

# Handle keypresses
_dip_key() {
  local key
  read -r -n 1 key
  
  # Handle arrow keys (escape sequences)
  if [[ "$key" == $'\x1b' ]]; then
    read -r -n 2 -t 0.1 rest
    key="$key$rest"
  fi
  
  case "$key" in
    $'\x1b[A') # Up
      [[ $_DIP_CURSOR -gt 0 ]] && ((_DIP_CURSOR--))
      ;;
    $'\x1b[B') # Down
      [[ $_DIP_CURSOR -lt $((${#_DIP_ENTRIES[@]} - 1)) ]] && ((_DIP_CURSOR++))
      ;;
    $'\x1b[D'|$'\x7f') # Left or backspace
      case $_DIP_VIEW in
        browse)
          # Go up a directory if not at BASE_DIR
          if [[ "$_DIP_DIR" != "$BASE_DIR" ]]; then
            local old_dir="$_DIP_DIR"
            _DIP_DIR=$(dirname "$_DIP_DIR")
            _dip_list_entries
            
            # Try to position cursor on directory we came from
            local old_base=$(basename "$old_dir")
            for ((i=0; i<${#_DIP_ENTRIES[@]}; i++)); do
              if [[ "${_DIP_ENTRIES[$i]}" == "$old_base" ]]; then
                _DIP_CURSOR=$i
                break
              fi
            done
          fi
          ;;
        metadata)
          # Back to browse mode
          _DIP_VIEW="browse"
          _DIP_CURSOR=0
          _dip_list_entries
          ;;
        files)
          # Back to metadata mode
          _DIP_VIEW="metadata"
          _DIP_CURSOR=0
          _dip_list_tags
          ;;
      esac
      ;;
    $'\x1b[C'|$'\n') # Right or enter
      case $_DIP_VIEW in
        browse)
          [[ ${#_DIP_ENTRIES[@]} -eq 0 ]] && return
          
          local item="${_DIP_ENTRIES[$_DIP_CURSOR]}"
          if [[ "$item" == ".." ]]; then
            # Go up a directory
            local old_dir="$_DIP_DIR"
            _DIP_DIR=$(dirname "$_DIP_DIR")
            _dip_list_entries
            
            # Try to position cursor on directory we came from
            local old_base=$(basename "$old_dir")
            for ((i=0; i<${#_DIP_ENTRIES[@]}; i++)); do
              if [[ "${_DIP_ENTRIES[$i]}" == "$old_base" ]]; then
                _DIP_CURSOR=$i
                break
              fi
            done
          elif [[ -d "$_DIP_DIR/$item/.meta" ]]; then
            # Enter metadata mode
            _DIP_ITEM="$item"
            _DIP_VIEW="metadata"
            _DIP_CURSOR=0
            _dip_list_tags
          else
            # Enter directory
            _DIP_DIR="$_DIP_DIR/$item"
            _DIP_CURSOR=0
            _dip_list_entries
          fi
          ;;
        metadata)
          [[ ${#_DIP_ENTRIES[@]} -eq 0 ]] && return
          
          # Enter tag files mode
          _DIP_TAG="${_DIP_ENTRIES[$_DIP_CURSOR]}"
          _DIP_VIEW="files"
          _DIP_CURSOR=0
          _dip_list_files
          ;;
        files)
          # Edit the selected file
          [[ ${#_DIP_ENTRIES[@]} -eq 0 ]] && return
          _dip_edit_entry
          ;;
      esac
      ;;
    a|+) # Add
      case $_DIP_VIEW in
        browse)
          _dip_add_meta
          ;;
        metadata)
          _dip_add_tag
          ;;
        files)
          _dip_add_entry
          ;;
      esac
      ;;
    d) # Delete
      case $_DIP_VIEW in
        browse)
          _dip_delete_meta
          ;;
        metadata)
          [[ ${#_DIP_