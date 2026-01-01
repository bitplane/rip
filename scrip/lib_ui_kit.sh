#!/usr/bin/env bash

#
# ui widget kit - scene graph for TUI applications
#
# Tree structure on disk:
#   /tmp/ui_xxx/              # root widget
#   ├── .meta/
#   │   ├── ui.type/0         # space-delimited traits, e.g., "list scrollable focusable"
#   │   ├── ui.pos/0          # "x y" relative to parent
#   │   ├── ui.size/0         # "w h"
#   │   ├── ui.clip/0         # "x y w h" visible region
#   │   ├── ui.buffer/0       # tab-delimited character buffer
#   │   ├── ui.rendered/0     # timestamp of last render
#   │   └── ui.focused/0      # path to focused child widget
#   ├── 0/                    # first child
#   ├── 1/                    # second child
#   └── 2/                    # third child
#
# Render pipeline:
#   1. Walk tree depth-first
#   2. For each dirty widget, call ui_widget_<trait>_draw for each trait
#   3. Composite all buffers in one awk call
#   4. Output to terminal
#
# Event dispatch:
#   1. Try each trait's ui_widget_<trait>_event in order
#   2. First handler returning 0 stops dispatch
#   3. If no handler returns 0, bubble to parent widget
#

# Create the root widget (usually a screen)
# Usage: root=$(ui_kit_init)
ui_kit_init() {
    local root
    root=$(mktemp -d)
    echo "$root"
}

# Adds a widget to the tree
# Usage: path=$(ui_kit_add parent type x y w h [focusable])
ui_kit_add() {
    local parent="$1" wtype="$2" x="$3" y="$4" w="$5" h="$6" focusable="${7:-0}"
    local idx path

    # Count existing children to get next index
    idx=$(find "$parent" -maxdepth 1 -mindepth 1 -type d ! -name '.meta' 2>/dev/null | wc -l)
    path="$parent/$idx"

    mkdir -p "$path"
    echo "$wtype"           | meta_set "ui.type"      0 "$path"
    echo "$x $y"            | meta_set "ui.pos"       0 "$path"
    echo "$w $h"            | meta_set "ui.size"      0 "$path"
    echo "0 0 $w $h"        | meta_set "ui.clip"      0 "$path"
    echo "$focusable"       | meta_set "ui.focusable" 0 "$path"
    ui_kit_blit_new "$w" "$h" | meta_set "ui.buffer"  0 "$path"

    echo "$path"
}

# Remove a widget and all its children
# Usage: ui_kit_remove path
ui_kit_remove() {
    local path="$1"
    local parent idx

    [[ ! -d "$path" ]] && return 1

    # Get parent path (everything except last component)
    parent=$(dirname "$path")

    # Remove the widget directory
    rm -rf "$path"

    # Renumber siblings to keep sequential ordering
    ui_kit_reindex "$parent"
}

# Renumber child widgets to be sequential (0, 1, 2...)
# Called after removal to close gaps
# Usage: ui_kit_reindex parent
ui_kit_reindex() {
    local parent="$1"
    local temp idx=0

    temp=$(mktemp -d)

    # Move all children to temp with new indices
    while IFS= read -r child; do
        [[ -z "$child" ]] && continue
        mv "$child" "$temp/$idx"
        ((idx++))
    done < <(find "$parent" -maxdepth 1 -mindepth 1 -type d ! -name '.meta' 2>/dev/null | sort -V)

    # Move back
    for child in "$temp"/*; do
        [[ -d "$child" ]] && mv "$child" "$parent/"
    done

    rm -rf "$temp"
}

# List children of a widget in order
# Usage: ui_kit_children path
ui_kit_children() {
    local path="$1"
    find "$path" -maxdepth 1 -mindepth 1 -type d ! -name '.meta' 2>/dev/null | sort -V
}

# Get widget property
# Usage: value=$(ui_kit_get path property)
ui_kit_get() {
    meta_get "ui.$2" 0 "$1"
}

# Set widget property
# Usage: echo "value" | ui_kit_set path property
ui_kit_set() {
    meta_set "ui.$2" 0 "$1"
}

# Check if widget needs redraw
# Dirty if any ui.* metadata is newer than last render timestamp
# Usage: ui_kit_is_dirty path
ui_kit_is_dirty() {
    local path="$1"
    local rendered="$path/.meta/ui.rendered/0"

    # Always dirty if never rendered
    [[ ! -f "$rendered" ]] && return 0

    # Dirty if any metadata file is newer than last render
    [[ -n "$(find "$path/.meta" -maxdepth 2 -name '0' -newer "$rendered" ! -path "*/ui.rendered/*" ! -path "*/ui.buffer/*" 2>/dev/null | head -1)" ]]
}

# Mark widget as just rendered (update timestamp)
# Usage: ui_kit_mark_rendered path
ui_kit_mark_rendered() {
    mkdir -p "$1/.meta/ui.rendered"
    touch "$1/.meta/ui.rendered/0"
}

# Force widget to be dirty (touch a metadata file)
# Usage: ui_kit_dirty path
ui_kit_dirty() {
    touch "$1/.meta/ui.type/0" 2>/dev/null
}

# Get widget dimensions as "w h"
# Usage: read w h <<< "$(ui_kit_size path)"
ui_kit_size() {
    ui_kit_get "$1" "size"
}

# Get widget position as "x y"
# Usage: read x y <<< "$(ui_kit_pos path)"
ui_kit_pos() {
    ui_kit_get "$1" "pos"
}

# Set widget position
# Usage: ui_kit_set_pos path x y
ui_kit_set_pos() {
    echo "$2 $3" | ui_kit_set "$1" "pos"
}

# Set widget size
# Usage: ui_kit_set_size path w h
ui_kit_set_size() {
    echo "$2 $3" | ui_kit_set "$1" "size"
}

# Get widget absolute position (by summing positions up to root)
# Usage: read ax ay <<< "$(ui_kit_abs_pos path)"
ui_kit_abs_pos() {
    local path="$1"
    local files="" p="$path"

    # Build list of pos files from widget up to root
    while [[ -d "$p/.meta" ]]; do
        files="$p/.meta/ui.pos/0 $files"
        p=$(dirname "$p")
        [[ "$p" == "/" || "$p" == "." ]] && break
    done

    # One awk call to sum all positions
    awk 'BEGIN { x=0; y=0 } { x+=$1; y+=$2 } END { print x, y }' $files
}

# Convert absolute coords to relative coords for a widget
# Usage: read rx ry <<< "$(ui_kit_rel_pos path abs_x abs_y)"
ui_kit_rel_pos() {
    local path="$1" ax="$2" ay="$3" wx wy

    read wx wy <<< "$(ui_kit_abs_pos "$path")"
    echo "$((ax - wx)) $((ay - wy))"
}

#
# Event dispatch
#

# Dispatch event to widget, bubble up if not handled
# Returns 0 if handled, 1 if not
# Usage: ui_event path event [args...]
ui_event() {
    local path="$1" event="$2"
    shift 2
    local wtype parent

    # Try each trait's handler in order
    for wtype in $(ui_kit_get "$path" "type"); do
        if type "ui_widget_${wtype}_event" &>/dev/null; then
            "ui_widget_${wtype}_event" "$path" "$event" "$@" && return 0
        fi
    done

    # Bubble to parent
    parent=$(dirname "$path")
    [[ "$parent" != "$path" && -d "$parent/.meta" ]] && ui_event "$parent" "$event" "$@"
}

#
# Focus management
#

# Get currently focused widget path
# Usage: focused=$(ui_kit_get_focus root)
ui_kit_get_focus() {
    ui_kit_get "$1" "focused"
}

# Set focus to a widget (sends focus:out/focus:in events)
# Usage: ui_kit_set_focus root target
ui_kit_set_focus() {
    local root="$1" target="$2"
    local current

    current=$(ui_kit_get_focus "$root")

    # Send focus:out to current
    [[ -n "$current" && -d "$current" ]] && ui_event "$current" "focus:out"

    # Update focus
    echo "$target" | ui_kit_set "$root" "focused"

    # Send focus:in to new target
    [[ -n "$target" && -d "$target" ]] && ui_event "$target" "focus:in"
}

#
# Tree traversal
#

# Walk the tree depth-first, calling a function for each widget
# Usage: ui_kit_walk root callback
# Callback receives: path depth
ui_kit_walk() {
    local root="$1" callback="$2" depth="${3:-0}"

    # Call callback for this node
    "$callback" "$root" "$depth"

    # Recurse into children
    while IFS= read -r child; do
        [[ -z "$child" ]] && continue
        ui_kit_walk "$child" "$callback" $((depth + 1))
    done < <(ui_kit_children "$root")
}

# Render the tree - redraw dirty widgets, composite all buffers in one awk call
# Usage: ui_kit_render root
ui_kit_render() {
    local root="$1" manifest script_dir
    manifest=$(mktemp)
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # First pass: redraw any dirty widgets to their buffer files
    ui_kit_walk "$root" _ui_kit_redraw_if_dirty

    # Second pass: build manifest of all buffers with absolute positions
    _ui_kit_build_manifest "$root" "" > "$manifest"

    # Composite everything in one awk call
    awk -f "$script_dir/buffer_blit.awk" < "$manifest"

    rm -f "$manifest"
}

# Internal: redraw a widget if dirty
_ui_kit_redraw_if_dirty() {
    local path="$1" depth="$2"
    local wtype

    if ui_kit_is_dirty "$path"; then
        # Call draw function for each trait
        for wtype in $(ui_kit_get "$path" "type"); do
            if type "ui_widget_${wtype}_draw" &>/dev/null; then
                "ui_widget_${wtype}_draw" "$path"
            fi
        done

        ui_kit_mark_rendered "$path"
    fi
}

# Internal: build manifest of buffer paths and absolute positions with clipping
# Output format: buffer_path screen_x screen_y buf_x buf_y width height
# Args: path parent_abs parent_clip
#   parent_abs: "ax ay" absolute position of parent
#   parent_clip: "cx cy cw ch" absolute clip region from parent
_ui_kit_build_manifest() {
    local path="$1" parent_abs="$2" parent_clip="$3"
    local px py ax ay w h buf_file child
    local cx cy cw ch  # clip region (absolute coords)
    local bx by bw bh  # buffer region to copy
    local sx sy        # screen position to draw at

    # Get position relative to parent
    read px py <<< "$(ui_kit_pos "$path")"
    read w h <<< "$(ui_kit_size "$path")"

    # Calculate absolute position
    if [[ -n "$parent_abs" ]]; then
        read pax pay <<< "$parent_abs"
        ax=$((pax + px))
        ay=$((pay + py))
    else
        ax=${px:-0}
        ay=${py:-0}
    fi

    # Calculate clip region by intersecting with parent's clip
    if [[ -n "$parent_clip" ]]; then
        read pcx pcy pcw pch <<< "$parent_clip"
        # Intersect this widget's bounds with parent's clip region
        cx=$ax
        cy=$ay
        cw=$w
        ch=$h

        # Clip left edge
        if [[ $cx -lt $pcx ]]; then
            cw=$((cw - (pcx - cx)))
            cx=$pcx
        fi
        # Clip top edge
        if [[ $cy -lt $pcy ]]; then
            ch=$((ch - (pcy - cy)))
            cy=$pcy
        fi
        # Clip right edge
        local right=$((cx + cw))
        local pright=$((pcx + pcw))
        if [[ $right -gt $pright ]]; then
            cw=$((pright - cx))
        fi
        # Clip bottom edge
        local bottom=$((cy + ch))
        local pbottom=$((pcy + pch))
        if [[ $bottom -gt $pbottom ]]; then
            ch=$((pbottom - cy))
        fi
    else
        # Root widget - clip region is just its own bounds
        cx=$ax
        cy=$ay
        cw=$w
        ch=$h
    fi

    # Skip if completely clipped out
    if [[ $cw -le 0 || $ch -le 0 ]]; then
        return
    fi

    # Calculate buffer offset and screen position
    # bx/by = how much of the buffer to skip (due to left/top clipping)
    bx=$((cx - ax))
    by=$((cy - ay))
    bw=$cw
    bh=$ch
    sx=$cx
    sy=$cy

    # Buffer file path
    buf_file="$path/.meta/ui.buffer/0"

    # Output manifest line for this widget
    if [[ -f "$buf_file" ]]; then
        echo "$buf_file $sx $sy $bx $by $bw $bh"
    fi

    # Recurse into children, passing our clip region
    while IFS= read -r child; do
        [[ -z "$child" ]] && continue
        _ui_kit_build_manifest "$child" "$ax $ay" "$cx $cy $cw $ch"
    done < <(ui_kit_children "$path")
}

# Destroy the entire widget tree
# Usage: ui_kit_destroy root
ui_kit_destroy() {
    rm -rf "$1"
}

#
# Built-in trait handlers
#

# focusable - handles focus:in and focus:out events
ui_widget_focusable_event() {
    local path="$1" event="$2"
    case "$event" in
        focus:in)
            echo "1" | ui_kit_set "$path" "has_focus"
            ui_kit_dirty "$path"
            return 0
            ;;
        focus:out)
            echo "0" | ui_kit_set "$path" "has_focus"
            ui_kit_dirty "$path"
            return 0
            ;;
    esac
    return 1
}
