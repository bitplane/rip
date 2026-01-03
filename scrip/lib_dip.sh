#!/usr/bin/env bash
# dip.sh - Minimal metadata editor for archive.org items
# Part of the "rip" tool suite - UI Kit version

# Global state
_DIP_DIR=""
_DIP_VIEW="browse"
_DIP_ITEM=""
_DIP_TAG=""
_DIP_HEADER=""
_DIP_LIST=""
_DIP_STATUS=""
_DIP_CONFIRM=""
_DIP_CONFIRM_ACTION=""
_DIP_CONFIRM_TARGET=""

# App event handler - receives bubbled events
ui_widget_dip_event() {
    local path="$1" event="$2"
    shift 2

    case "$event" in
        key)
            _dip_handle_key "$1"
            return 0
            ;;
        activate)
            # List item activated (enter pressed)
            _dip_select
            return 0
            ;;
        confirm)
            # Yes pressed in confirm dialog
            _dip_do_confirm
            return 0
            ;;
        cancel)
            # No pressed in confirm dialog
            _dip_hide_confirm
            return 0
            ;;
    esac
    return 1
}

# Handle key presses
_dip_handle_key() {
    local key="$1"

    # If confirm dialog is visible, let it handle keys
    [[ -d "$_DIP_CONFIRM" ]] && return 1

    case "$key" in
        a|+)
            _dip_add
            ;;
        d)
            _dip_delete
            ;;
        e)
            [[ $_DIP_VIEW == "files" ]] && _dip_edit_entry
            ;;
        backspace|left)
            _dip_back
            ;;
        q)
            ui_kit_quit
            ;;
    esac
}

# Navigate back
_dip_back() {
    case $_DIP_VIEW in
        browse)
            # Go up a directory if not at base
            [[ "$_DIP_DIR" != "$BASE_DIR" ]] && {
                _DIP_DIR=$(dirname "$_DIP_DIR")
                _dip_refresh
            }
            ;;
        metadata)
            _DIP_VIEW="browse"
            _dip_refresh
            ;;
        files)
            _DIP_VIEW="metadata"
            _dip_refresh
            ;;
    esac
}

# Select current item
_dip_select() {
    local selected
    selected=$(<"$_DIP_LIST/selected")
    local item
    item=$(sed -n "$((selected + 1))p" "$_DIP_LIST/contents")

    case $_DIP_VIEW in
        browse)
            if [[ "$item" == ".." ]]; then
                _DIP_DIR=$(dirname "$_DIP_DIR")
                _dip_refresh
            elif [[ -d "$_DIP_DIR/$item/.meta" ]]; then
                _DIP_ITEM="$item"
                _DIP_VIEW="metadata"
                _dip_refresh
            else
                _DIP_DIR="$_DIP_DIR/$item"
                _dip_refresh
            fi
            ;;
        metadata)
            _DIP_TAG="$item"
            _DIP_VIEW="files"
            _dip_refresh
            ;;
        files)
            _dip_edit_entry
            ;;
    esac
}

# Add item based on current view
_dip_add() {
    case $_DIP_VIEW in
        browse)
            local selected
            selected=$(<"$_DIP_LIST/selected")
            local item
            item=$(sed -n "$((selected + 1))p" "$_DIP_LIST/contents")
            [[ "$item" == ".." ]] && return
            mkdir -p "$_DIP_DIR/$item/.meta"
            _dip_refresh
            ;;
        metadata)
            _dip_add_tag
            ;;
        files)
            _dip_add_entry
            ;;
    esac
}

# Add tag with editor
_dip_add_tag() {
    local temp
    temp=$(mktemp)
    echo "# Enter tag name on first line" > "$temp"

    _dip_run_editor "$temp"

    local tag
    tag=$(head -n 1 "$temp" | grep -v '^#')
    rm "$temp"

    [[ -n "$tag" ]] && {
        mkdir -p "$_DIP_DIR/$_DIP_ITEM/.meta/$tag"
        _dip_refresh
    }
}

# Add entry to current tag
_dip_add_entry() {
    local path="$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG"
    local count
    count=$(find "$path" -maxdepth 1 -type f 2>/dev/null | wc -l)
    local temp
    temp=$(mktemp)

    _dip_run_editor "$temp"

    [[ -s "$temp" ]] && {
        cat "$temp" > "$path/$count"
        meta_touch "$path"
    }
    rm "$temp"
    _dip_refresh
}

# Edit current entry
_dip_edit_entry() {
    local selected
    selected=$(<"$_DIP_LIST/selected")
    local file
    file=$(sed -n "$((selected + 1))p" "$_DIP_LIST/contents")
    local path="$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG/$file"

    _dip_run_editor "$path"
    meta_touch "$path"
    _dip_refresh
}

# Run editor, handling terminal state
_dip_run_editor() {
    local file="$1"
    local editor=${VISUAL:-${EDITOR:-vi}}
    local git_editor
    git_editor=$(git config --get core.editor 2>/dev/null)
    [[ -n "$git_editor" ]] && editor="$git_editor"

    # Restore terminal for editor
    ui_kit_cleanup
    $editor "$file"
    ui_kit_init_term
}

# Delete with confirmation
_dip_delete() {
    local selected
    selected=$(<"$_DIP_LIST/selected")
    local item
    item=$(sed -n "$((selected + 1))p" "$_DIP_LIST/contents")

    [[ -z "$item" || "$item" == ".." ]] && return

    local message
    case $_DIP_VIEW in
        browse)
            message="Delete ALL metadata for $item?"
            _DIP_CONFIRM_ACTION="meta"
            ;;
        metadata)
            message="Delete tag $item and ALL entries?"
            _DIP_CONFIRM_ACTION="tag"
            ;;
        files)
            message="Delete entry $item?"
            _DIP_CONFIRM_ACTION="entry"
            ;;
    esac
    _DIP_CONFIRM_TARGET="$item"

    _dip_show_confirm "$message"
}

# Show confirm dialog
_dip_show_confirm() {
    local message="$1"
    local w h x y
    read w h < "$_UI_KIT_ROOT/size"
    local dw=44 dh=5
    x=$(( (w - dw) / 2 ))
    y=$(( (h - dh) / 2 ))

    _DIP_CONFIRM=$(ui_widget_confirm "$_UI_KIT_ROOT" "$message" "$x" "$y" "$dw")
}

# Hide confirm dialog
_dip_hide_confirm() {
    [[ -d "$_DIP_CONFIRM" ]] && {
        rm -rf "$_DIP_CONFIRM"
        ui_kit_set_focus "$_DIP_LIST"
        ui_kit_dirty "$_UI_KIT_ROOT"
    }
    _DIP_CONFIRM=""
}

# Execute confirmed action
_dip_do_confirm() {
    case $_DIP_CONFIRM_ACTION in
        meta)
            meta_rm "*" "*" "$_DIP_DIR/$_DIP_CONFIRM_TARGET"
            ;;
        tag)
            meta_rm "$_DIP_CONFIRM_TARGET" "*" "$_DIP_DIR/$_DIP_ITEM"
            ;;
        entry)
            meta_rm "$_DIP_TAG" "$_DIP_CONFIRM_TARGET" "$_DIP_DIR/$_DIP_ITEM"
            ;;
    esac
    _dip_hide_confirm
    _dip_refresh
}

# Refresh the list contents
_dip_refresh() {
    local contents=""

    case $_DIP_VIEW in
        browse)
            # Add parent if not at base
            [[ "$_DIP_DIR" != "$BASE_DIR" ]] && contents=".."$'\n'
            # Add directories
            contents+=$(find "$_DIP_DIR" -maxdepth 1 -mindepth 1 -type d -not -path "*/\.*" -printf "%f\n" 2>/dev/null | sort)
            echo "Directory: $_DIP_DIR" > "$_DIP_HEADER/text"
            echo "↑↓:nav  →/Enter:select  a:add meta  d:delete  q:quit" > "$_DIP_STATUS/text"
            ;;
        metadata)
            contents=$(meta_tags "$_DIP_DIR/$_DIP_ITEM" 2>/dev/null | sort)
            echo "Metadata: $_DIP_ITEM" > "$_DIP_HEADER/text"
            echo "↑↓:nav  →/Enter:select  ←:back  a:add tag  d:delete  q:quit" > "$_DIP_STATUS/text"
            ;;
        files)
            contents=$(find "$_DIP_DIR/$_DIP_ITEM/.meta/$_DIP_TAG" -maxdepth 1 -mindepth 1 -type f -printf "%f\n" 2>/dev/null | sort -n)
            echo "Tag: $_DIP_TAG" > "$_DIP_HEADER/text"
            echo "↑↓:nav  Enter/e:edit  ←:back  a:add entry  d:delete  q:quit" > "$_DIP_STATUS/text"
            ;;
    esac

    echo "$contents" > "$_DIP_LIST/contents"
    echo "0" > "$_DIP_LIST/selected"
    echo "0" > "$_DIP_LIST/scroll"
    ui_kit_dirty "$_DIP_HEADER"
    ui_kit_dirty "$_DIP_STATUS"
    ui_kit_dirty "$_DIP_LIST"
}

# Main function
dip_main() {
    _DIP_DIR="${1:-$BASE_DIR}"

    # Create UI
    ui_kit_init
    echo "dip root" > "$_UI_KIT_ROOT/type"

    local w h
    read w h < "$_UI_KIT_ROOT/size"

    # Header label
    _DIP_HEADER=$(ui_widget_label "$_UI_KIT_ROOT" "" 0 0 "$w" $'\e[44m\e[97m')

    # Main list
    _DIP_LIST=$(echo "" | ui_widget_list "$_UI_KIT_ROOT" 0 1 "$w" $((h - 2)))

    # Status bar
    _DIP_STATUS=$(ui_widget_label "$_UI_KIT_ROOT" "" 0 $((h - 1)) "$w" $'\e[100m\e[97m')

    # Initial content
    _dip_refresh
    ui_kit_set_focus "$_DIP_LIST"

    # Run
    ui_kit_run
}
