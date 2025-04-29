#!/usr/bin/env bash
# dip.sh - Minimal metadata editor for archive.org items
# Part of the "rip" tool suite

# Find the base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
source "$BASE_DIR/scrip/libs.sh"

# Global vars
_DIP_DIR="$BASE_DIR"
_DIP_CURSOR=0
_DIP_VIEW="browse"
_DIP_ITEM=""
_DIP_TAG=""
_DIP_ENTRIES=()
_DIP_STATUS_BAR=""
_DIP_STAGE_EMOJI=("💽" "👀" "📦" "🔝" "🍻")
_DIP_CACHE_DIR="/tmp/dip-cache-$$"

# Initialize terminal and cache
_dip_in() {
  # Setup terminal
  tput smcup
  tput civis
  stty -echo raw
  
  # Setup caching
  mkdir -p "$_DIP_CACHE_DIR"
  
  # Set traps
  trap _dip_out EXIT INT TERM
}

# Cleanup terminal and cache
_dip_out() {
  # Restore terminal
  tput rmcup
  tput cnorm
  stty echo -raw
  
  # Cleanup cache
  rm -rf "$_DIP_CACHE_DIR" 2>/dev/null
  
  exit 0
}

# Get stage emoji if applicable
_dip_get_emoji() {
  local dir="$1"
  local base=$(basename "$dir")
  
  # Skip dirs get ❌
  if [[ $base =~ \.skip$ ]]; then
    echo "❌"
    return
  fi
  
  # Check if the directory is a numbered stage or under a stage
  if [[ $base =~ ^[1-5]\. ]]; then
    local num=${base:0:1}
    echo "${_DIP_STAGE_EMOJI[$((num-1))]}"
  elif [[ $(dirname "$dir") =~ ^.*/[1-5]\. ]]; then
    local parent=$(basename "$(dirname "$dir")")
    local num=${parent:0:1}
    echo "${_DIP_STAGE_EMOJI[$((num-1))]}"
  else
    echo " "
  fi
}

# List directory entries
_dip_list_entries() {
  # Reset entries array
  _DIP_ENTRIES=()
  
  # Add parent directory if not at BASE_DIR
  [[ "$_DIP_DIR" != "$BASE_DIR" ]] && _DIP_ENTRIES+=("..")
  
  # Add directories
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    _DIP_ENTRIES+=("$entry")
  done < <(find "$_DIP_DIR" -maxdepth 1 -mindepth 1 -type d -not -path "*/\.*" -printf "%f\n" | sort)
  
  # Adjust cursor position if needed
  [[ $_DIP_CURSOR -ge ${#_DIP_ENTRIES[@]} ]] && _DIP_CURSOR=$((${#_DIP_ENTRIES[@]} - 1))
  [[ $_DIP_CURSOR -lt 0 ]] && _DIP_CURSOR=0
}

# List metadata tags
_dip_list_tags() {
  # Reset entries array
  _DIP_ENTRIES=()
  
  # Add tags
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    _DIP_ENTRIES+=("$tag")
  done < <(find "$_DIP_DIR/$_DIP_ITEM/.meta" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" 2>/dev/null | sort)
  
  # Adjust cursor position if needed
  [[ $_DIP_CURSOR -ge ${#_DIP_ENTRIES[@]} ]] && _DIP_CURSOR=$((${#_DIP_ENTRIES[@]} - 1))
  [[ $_DIP_CURSOR -lt 0 ]] && _DIP_CURSOR=0
}

# List tag files
_dip_list_files() {
  # Reset entries array
  _DIP_ENTRIES=()
  
  # Add files
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    _DIP_ENTRIES+=("$file")
  done < <(find "$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG" -maxdepth 1 -mindepth 1 -type f -printf "%f\n" 2>/dev/null | sort -n)
  
  # Adjust cursor position if needed
  [[ $_DIP_CURSOR -ge ${#_DIP_ENTRIES[@]} ]] && _DIP_CURSOR=$((${#_DIP_ENTRIES[@]} - 1))
  [[ $_DIP_CURSOR -lt 0 ]] && _DIP_CURSOR=0
}

# Draw a single row
_dip_row() {
  local selected=$1
  local symbol=$2
  local text=$3
  local details=${4:-""}
  
  # Format based on selection
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

# Draw screen with caching
_dip_draw() {
  local cache_file="$_DIP_CACHE_DIR/entries.cache"
  local cache_meta="$_DIP_CACHE_DIR/cache_meta"
  local term_height=$(tput lines)
  local visible_rows=$((term_height - 4))
  
  # Get directory information
  local current_path=""
  local mtime=""
  case $_DIP_VIEW in
    browse)
      current_path="$_DIP_DIR"
      mtime=$(stat -c "%Y" "$_DIP_DIR" 2>/dev/null)
      ;;
    metadata)
      current_path="$_DIP_DIR/$_DIP_ITEM/.meta"
      mtime=$(stat -c "%Y" "$current_path" 2>/dev/null)
      ;;
    files)
      current_path="$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG"
      mtime=$(stat -c "%Y" "$current_path" 2>/dev/null)
      ;;
  esac
  
  # Check if cache needs regeneration based on mtime
  local regenerate=0
  if [[ ! -f "$cache_file" ]]; then
    regenerate=1
  elif [[ ! -f "$cache_meta" ]]; then
    regenerate=1
  else
    local cached_path=$(sed -n '1p' "$cache_meta")
    local cached_mtime=$(sed -n '2p' "$cache_meta")
    local cached_view=$(sed -n '3p' "$cache_meta")
    
    if [[ "$cached_path" != "$current_path" || "$cached_mtime" != "$mtime" || "$cached_view" != "$_DIP_VIEW" ]]; then
      regenerate=1
    fi
  fi
  
  # Regenerate cache if needed
  if [[ $regenerate -eq 1 ]]; then
    # Store cache metadata
    echo "$current_path" > "$cache_meta"
    echo "$mtime" >> "$cache_meta"
    echo "$_DIP_VIEW" >> "$cache_meta"
    
    # Generate cache
    _dip_generate_cache
  fi
  
  # Clear screen
  clear
  
  # Draw header
  tput bold
  case $_DIP_VIEW in
    browse)
      printf "Directory: %s\r\n" "$_DIP_DIR"
      _DIP_STATUS_BAR="Arrows: navigate | Return: select | a: add meta | d: delete meta | q: quit"
      ;;
    metadata)
      printf "Metadata for: %s\r\n" "$_DIP_ITEM"
      _DIP_STATUS_BAR="Arrows: navigate | Return: select | a: add tag | d: delete tag | q: quit"
      ;;
    files)
      printf "Tag: %s in %s\r\n" "$_DIP_TAG" "$_DIP_ITEM"
      _DIP_STATUS_BAR="Arrows: navigate | Return/e: edit | a: add entry | d: delete | q: quit"
      ;;
  esac
  tput sgr0
  
  # Draw divider
  printf "────────────────────────────────────────────────────\r\n"
  
  # Calculate start index for scrolling
  local start_idx=0
  if [[ ${#_DIP_ENTRIES[@]} -gt $visible_rows ]]; then
    # Center cursor in view when possible
    local half_view=$((visible_rows / 2))
    
    if [[ $_DIP_CURSOR -ge $half_view ]]; then
      start_idx=$((_DIP_CURSOR - half_view))
    fi
    
    # Don't scroll past end
    if [[ $((start_idx + visible_rows)) -gt ${#_DIP_ENTRIES[@]} ]]; then
      start_idx=$((${#_DIP_ENTRIES[@]} - visible_rows))
    fi
  fi
  
  # Calculate end index
  local end_idx=$((start_idx + visible_rows))
  [[ $end_idx -gt ${#_DIP_ENTRIES[@]} ]] && end_idx=${#_DIP_ENTRIES[@]}
  
  # Display cache up to cursor position
  if [[ $start_idx -lt $_DIP_CURSOR ]]; then
    head -n $_DIP_CURSOR "$cache_file" | tail -n $((_DIP_CURSOR - start_idx))
  fi
  
  # Draw highlighted row
  local entry="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  local symbol=" "
  local details=""
  
  case $_DIP_VIEW in
    browse)
      [[ "$entry" != ".." ]] && symbol=$(_dip_get_emoji "$_DIP_DIR/$entry")
      
      if [[ "$entry" != ".." && -d "$_DIP_DIR/$entry/.meta" ]]; then
        local tags=$(find "$_DIP_DIR/$entry/.meta" -maxdepth 1 -mindepth 1 -type d -printf "%f " 2>/dev/null | head -c 40)
        details="${tags:-(no tags)}"
        _dip_row 1 "$symbol" "[$entry]" "$details"
      else
        _dip_row 1 "$symbol" "$entry"
      fi
      ;;
    metadata)
      local count=$(find "$_DIP_DIR/$_DIP_ITEM/.meta/$entry" -type f 2>/dev/null | wc -l)
      
      if [[ $count -gt 0 ]]; then
        local preview=$(cat "$_DIP_DIR/$_DIP_ITEM/.meta/$entry/0" 2>/dev/null | head -n 1 | cut -c 1-40)
        [[ ${#preview} -gt 39 ]] && preview="${preview:0:37}..."
        details="$preview"
      else
        details="(empty)"
      fi
      
      _dip_row 1 "$symbol" "$entry ($count):" "$details"
      ;;
    files)
      local content=$(cat "$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG/$entry" 2>/dev/null | head -n 1 | cut -c 1-50)
      [[ ${#content} -gt 49 ]] && content="${content:0:47}..."
      
      _dip_row 1 "$symbol" "$entry:" "$content"
      ;;
  esac
  
  # Display cache after cursor position
  if [[ $_DIP_CURSOR -lt $((end_idx - 1)) ]]; then
    total_entries=${#_DIP_ENTRIES[@]}
    remaining=$((total_entries - _DIP_CURSOR - 1))
    to_display=$((end_idx - _DIP_CURSOR - 1))
    head -n $to_display <(tail -n $remaining "$cache_file")
  fi
  
  # Draw status bar
  tput cup $((term_height - 2)) 0
  tput bold
  printf "%s\r\n" "$_DIP_STATUS_BAR"
  tput sgr0
}

# Generate cache of all entries (without highlighting)
_dip_generate_cache() {
  local cache_file="$_DIP_CACHE_DIR/entries.cache"
  > "$cache_file" # Clear cache file
  
  for ((i=0; i<${#_DIP_ENTRIES[@]}; i++)); do
    local entry="${_DIP_ENTRIES[$i]}"
    local symbol=" "
    local details=""
    
    # Skip cursor position - we'll render that separately
    [[ $i -eq $_DIP_CURSOR ]] && continue
    
    case $_DIP_VIEW in
      browse)
        [[ "$entry" != ".." ]] && symbol=$(_dip_get_emoji "$_DIP_DIR/$entry")
        
        if [[ "$entry" != ".." && -d "$_DIP_DIR/$entry/.meta" ]]; then
          local tags=$(find "$_DIP_DIR/$entry/.meta" -maxdepth 1 -mindepth 1 -type d -printf "%f " 2>/dev/null | head -c 40)
          details="${tags:-(no tags)}"
          printf " %s [%s] " "$symbol" "$entry" >> "$cache_file"
          tput setaf 6 >> "$cache_file"
          printf "%s\r\n" "$details" >> "$cache_file"
          tput sgr0 >> "$cache_file"
        else
          printf " %s %s\r\n" "$symbol" "$entry" >> "$cache_file"
        fi
        ;;
      metadata)
        local count=$(find "$_DIP_DIR/$_DIP_ITEM/.meta/$entry" -type f 2>/dev/null | wc -l)
        
        if [[ $count -gt 0 ]]; then
          local preview=$(cat "$_DIP_DIR/$_DIP_ITEM/.meta/$entry/0" 2>/dev/null | head -n 1 | cut -c 1-40)
          [[ ${#preview} -gt 39 ]] && preview="${preview:0:37}..."
          details="$preview"
        else
          details="(empty)"
        fi
        
        printf " %s %s (%d): " "$symbol" "$entry" "$count" >> "$cache_file"
        tput setaf 6 >> "$cache_file"
        printf "%s\r\n" "$details" >> "$cache_file"
        tput sgr0 >> "$cache_file"
        ;;
      files)
        local content=$(cat "$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG/$entry" 2>/dev/null | head -n 1 | cut -c 1-50)
        [[ ${#content} -gt 49 ]] && content="${content:0:47}..."
        
        printf " %s %s: %s\r\n" "$symbol" "$entry" "$content" >> "$cache_file"
        ;;
    esac
  done
}

# Invalidate cache
_dip_cache_clear() {
  rm -f "$_DIP_CACHE_DIR"/* 2>/dev/null
}

# Add metadata tag
_dip_add_tag() {
  local item="$_DIP_DIR/$_DIP_ITEM"
  
  # Return to normal terminal mode for input
  tput cnorm
  stty echo -raw
  
  # Prompt for tag name
  tput cup $(($(tput lines) - 1)) 0
  tput el
  echo -n "Enter tag name: "
  read -r tag
  
  # If not empty, create tag
  if [[ -n "$tag" ]]; then
    mkdir -p "$item/.meta/$tag"
    # Add first entry immediately
    _dip_add_entry "$tag"
  fi
  
  # Return to raw mode
  stty -echo raw
  tput civis
  
  # Clear cache
  _dip_cache_clear
}

# Add entry to tag
_dip_add_entry() {
  local tag="${1:-$_DIP_TAG}"
  local item="$_DIP_DIR/$_DIP_ITEM"
  local path="$item/.meta/$tag"
  local count=$(find "$path" -type f 2>/dev/null | wc -l)
  local temp=$(mktemp)
  
  # Get editor (git editor preferred)
  local editor=${VISUAL:-${EDITOR:-vi}}
  local git_editor=$(git config --get core.editor 2>/dev/null)
  [[ -n "$git_editor" ]] && editor="$git_editor"
  
  # Return to normal terminal for editor
  tput rmcup
  tput cnorm
  stty echo -raw
  
  # Edit file
  $editor "$temp"
  
  # Save if not empty
  [[ -s "$temp" ]] && cat "$temp" > "$path/$count"
  
  # Cleanup
  rm "$temp"
  
  # Return to TUI mode
  tput smcup
  stty -echo raw
  tput civis
  
  # Clear cache
  _dip_cache_clear
}

# Edit tag entry
_dip_edit_entry() {
  local file="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  local path="$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG/$file"
  
  # Get editor
  local editor=${VISUAL:-${EDITOR:-vi}}
  local git_editor=$(git config --get core.editor 2>/dev/null)
  [[ -n "$git_editor" ]] && editor="$git_editor"
  
  # Return to normal terminal for editor
  tput rmcup
  tput cnorm
  stty echo -raw
  
  # Edit file
  $editor "$path"
  
  # Return to TUI mode
  tput smcup
  stty -echo raw
  tput civis
  
  # Clear cache
  _dip_cache_clear
}

# Delete tag entry
_dip_delete_entry() {
  local file="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  # Confirm deletion
  tput cup $(($(tput lines) - 1)) 0
  tput el
  echo -n "Delete entry $file? [y/N] "
  
  read -r -n 1 confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    # Use the meta_del function from libs.sh
    meta_del "$_DIP_DIR/$_DIP_ITEM" "$_DIP_TAG" "$file"
    # Refresh the list
    _dip_list_files
    # Clear cache
    _dip_cache_clear
  fi
}

# Delete metadata tag
_dip_delete_tag() {
  local tag="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  # Confirm deletion
  tput cup $(($(tput lines) - 1)) 0
  tput el
  echo -n "Delete tag $tag and ALL entries? [y/N] "
  
  read -r -n 1 confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    # Delete the tag directory
    rm -rf "$_DIP_DIR/$_DIP_ITEM/.meta/$tag"
    
    # Refresh the list
    _dip_list_tags
    
    # Clear cache
    _dip_cache_clear
  fi
}

# Delete all metadata
_dip_delete_meta() {
  local item="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  # Skip special entries
  [[ "$item" == ".." ]] && return
  
  # Confirm deletion
  tput cup $(($(tput lines) - 1)) 0
  tput el
  echo -n "Delete ALL metadata for $item? [y/N] "
  
  read -r -n 1 confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    rm -rf "$_DIP_DIR/$item/.meta"
    
    # Clear cache
    _dip_cache_clear
  fi
}

# Add metadata to item
_dip_add_meta() {
  local item="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  # Skip special entries
  [[ "$item" == ".." ]] && return
  
  # Create metadata dir
  mkdir -p "$_DIP_DIR/$item/.meta"
  
  # Clear cache
  _dip_cache_clear
}

# Get keypress and handle it
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
          _dip_list_files
          ;;
      esac
      ;;
    a|+) # Add
      case $_DIP_VIEW in
        browse)
          _dip_add_meta
          _dip_list_entries
          ;;
        metadata)
          _dip_add_tag
          _dip_list_tags
          ;;
        files)
          _dip_add_entry
          _dip_list_files
          ;;
      esac
      ;;
    d) # Delete
      case $_DIP_VIEW in
        browse)
          _dip_delete_meta
          _dip_list_entries
          ;;
        metadata)
          [[ ${#_DIP_ENTRIES[@]} -eq 0 ]] && return
          _dip_delete_tag
          _dip_list_tags
          ;;
        files)
          [[ ${#_DIP_ENTRIES[@]} -eq 0 ]] && return
          _dip_delete_entry
          _dip_list_files
          ;;
      esac
      ;;
    e) # Edit
      [[ $_DIP_VIEW == "files" && ${#_DIP_ENTRIES[@]} -gt 0 ]] && {
        _dip_edit_entry
        _dip_list_files
      }
      ;;
    q|$'\x1b') # Quit
      _dip_out
      ;;
  esac
}

# Main function
dip_main() {
  _dip_in
  _dip_list_entries
  
  # Main loop
  while true; do
    _dip_draw
    _dip_key
  done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dip_main
fi