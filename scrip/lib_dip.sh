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

# Initialize terminal
_dip_in() {
  # Terminal setup
  tput smcup
  tput civis
  stty -echo raw
  
  _DIP_CACHE_DIR="$(mktmp)"
  
  shell_trap "_dip_out $_DIP_CACHE_DIR"
}

# Cleanup and exit
_dip_out() {
  # Restore terminal
  reset

  # Clean up cache
  rm -rf "$1" 2>/dev/null
  
  exit 0
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
    done < <(meta_tags "$_DIP_DIR"/"$_DIP_ITEM" | sort)
  
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
  local message="$1" default="${2:-N}"
  
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
  
  # Clear screen
  clear
  
  # Draw header
  tput bold
  case $_DIP_VIEW in
    browse)
      printf "Directory: %s\r\n" "$_DIP_DIR"
      ;;
    metadata)
      printf "Metadata for: %s\r\n" "$_DIP_ITEM"
      ;;
    files)
      printf "Tag: %s in %s\r\n" "$_DIP_TAG" "$_DIP_ITEM"
      ;;
  esac
  tput sgr0
  
  # Calculate start index for scrolling
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
  
  # Draw entries
  local end_idx=$((start_idx + visible_rows))
  [[ $end_idx -gt ${#_DIP_ENTRIES[@]} ]] && end_idx=${#_DIP_ENTRIES[@]}
  
  for ((i=start_idx; i<end_idx; i++)); do
    local entry="${_DIP_ENTRIES[$i]}"
    local selected=0
    local symbol=" "
    local details=""
    
    [[ $i -eq $_DIP_CURSOR ]] && selected=1
    
    case $_DIP_VIEW in
      browse)
        [[ "$entry" != ".." ]] && symbol=$(ui_emoji "$_DIP_DIR/$entry")
        
        if [[ "$entry" != ".." && -d "$_DIP_DIR/$entry/.meta" ]]; then
          local tags=$(find "$_DIP_DIR/$entry/.meta" -maxdepth 1 -mindepth 1 -type d -printf "%f " 2>/dev/null | head -c 40)
          details="${tags:-(no tags)}"
          _dip_row $selected "$symbol" "[$entry]" "$details"
        else
          _dip_row $selected "$symbol" "$entry"
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
        
        _dip_row $selected "$symbol" "$entry ($count):" "$details"
        ;;
      files)
        local content=$(cat "$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG/$entry" 2>/dev/null | head -n 1 | cut -c 1-50)
        [[ ${#content} -gt 49 ]] && content="${content:0:47}..."
        
        _dip_row $selected "$symbol" "$entry:" "$content"
        ;;
    esac
  done
  
  # Draw status bar
  tput cup $((term_height - 2)) 0
  tput bold
  printf "%s\r\n" "$(_dip_status_bar)"
  tput sgr0
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
  
  # If not empty, create tag and add first entry
  if [[ -n "$tag" ]]; then
    mkdir -p "$_DIP_DIR/$_DIP_ITEM/.meta/$tag"
    _dip_add_entry "$tag"
    _dip_list_tags
  fi
  
  # Return to raw mode
  stty -echo raw
  tput civis
}

# Add entry to tag
_dip_add_entry() {
  local tag="${1:-$_DIP_TAG}"
  local path="$_DIP_DIR/$_DIP_ITEM/.meta/$tag"
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
  if [[ -s "$temp" ]]; then
    cat "$temp" > "$path/$count"
    meta_touch "$path"
  fi
  
  # Cleanup
  rm "$temp"
  
  # Return to TUI mode
  tput smcup
  stty -echo raw
  tput civis
  
  # Refresh list
  _dip_list_files
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
  
  # Update mtimes to invalidate any caches
  meta_touch "$path"
  
  # Return to TUI mode
  tput smcup
  stty -echo raw
  tput civis
}

# Delete tag entry with confirmation
_dip_delete_entry() {
  local file="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  if _dip_prompt "Delete entry $file? [y/N]" "N"; then
    meta_rm "$_DIP_TAG" "$file" "$_DIP_DIR/$_DIP_ITEM" 
    _dip_list_files
  fi
}

# Delete metadata tag with confirmation
_dip_delete_tag() {
  local tag="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  if _dip_prompt "Delete tag $tag and ALL entries? [y/N]" "N"; then
    meta_rm "$tag" "*" "$_DIP_DIR/$_DIP_ITEM"
    _dip_list_tags
  fi
}

# Delete all metadata with confirmation
_dip_delete_meta() {
  local item="${_DIP_ENTRIES[$_DIP_CURSOR]}"
  
  # Skip special entries
  [[ "$item" == ".." ]] && return
  

  if _dip_prompt "Delete ALL metadata for $item? [y/N]" "N"; then
    meta_rm "*" "*" "$_DIP_DIR/$item"
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
          [[ ${#_DIP_ENTRIES[@]} -eq 0 ]] && return
          _dip_delete_tag
          ;;
        files)
          [[ ${#_DIP_ENTRIES[@]} -eq 0 ]] && return
          _dip_delete_entry
          ;;
      esac
      ;;
    e) # Edit
      [[ $_DIP_VIEW == "files" && ${#_DIP_ENTRIES[@]} -gt 0 ]] && {
        _dip_edit_entry
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
