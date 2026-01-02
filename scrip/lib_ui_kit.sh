#!/usr/bin/env bash

#
# ui widget kit - scene graph for TUI applications
#
# Tree structure on disk:
#   /tmp/ui_xxx/              # root widget
#   ├── type                  # space-delimited traits, e.g., "list scrollable focusable"
#   ├── pos                   # "x y" relative to parent
#   ├── size                  # "w h"
#   ├── buffer                # tab-delimited character buffer
#   ├── rendered              # timestamp of last render
#   ├── focused               # (root only) path to currently focused widget
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

# Global root widget path
declare -g _UI_KIT_ROOT=""

# Create the root widget (usually a screen)
# Usage: ui_kit_init  (then use $_UI_KIT_ROOT)
ui_kit_init() {
    _UI_KIT_ROOT=$(mktemp -d)
    # Initialize focused to empty
    touch "$_UI_KIT_ROOT/focused"
}

# Adds a widget to the tree
# Usage: path=$(ui_kit_add parent type x y w h)
ui_kit_add() {
    local parent="$1" wtype="$2" x="$3" y="$4" w="$5" h="$6"
    local idx=0 path

    # Count existing children to get next index
    while [[ -d "$parent/$idx" ]]; do ((idx++)); done
    path="$parent/$idx"

    mkdir -p "$path"
    echo "$wtype"             > "$path/type"
    echo "$x $y"              > "$path/pos"
    echo "$w $h"              > "$path/size"
    ui_kit_blit_new "$w" "$h" > "$path/buffer"

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
    local temp i=0 new_idx=0

    temp=$(mktemp -d)

    # Move all children to temp with new indices
    while [[ -d "$parent/$i" ]]; do
        mv "$parent/$i" "$temp/$new_idx"
        ((new_idx++))
        ((i++))
    done

    # Move back
    i=0
    while [[ -d "$temp/$i" ]]; do
        mv "$temp/$i" "$parent/$i"
        ((i++))
    done

    rm -rf "$temp"
}

# List children of a widget in order
# Usage: ui_kit_children path
ui_kit_children() {
    local path="$1" i=0
    while [[ -d "$path/$i" ]]; do
        echo "$path/$i"
        ((i++))
    done
}

# Get widget property
# Usage: value=$(ui_kit_get path property)
ui_kit_get() {
    cat "$1/$2" 2>/dev/null
}

# Set widget property
# Usage: echo "value" | ui_kit_set path property
ui_kit_set() {
    cat > "$1/$2"
}

# Check if widget needs redraw
# Dirty if any property file is newer than last render timestamp
# Usage: ui_kit_is_dirty path
ui_kit_is_dirty() {
    local path="$1" f
    local rendered="$path/rendered"

    # Always dirty if never rendered
    [[ ! -f "$rendered" ]] && return 0

    # Dirty if any property file is newer than last render
    for f in "$path"/*; do
        [[ -f "$f" ]] || continue
        [[ "${f##*/}" == rendered || "${f##*/}" == buffer ]] && continue
        [[ "$f" -nt "$rendered" ]] && return 0
    done
    return 1
}

# Mark widget as just rendered (update timestamp)
# Usage: ui_kit_mark_rendered path
ui_kit_mark_rendered() {
    touch "$1/rendered"
}

# Force widget to be dirty (touch a property file)
# Usage: ui_kit_dirty path
ui_kit_dirty() {
    touch "$1/type" 2>/dev/null
}

# Get widget dimensions as "w h"
# Usage: read w h <<< "$(ui_kit_size path)"
ui_kit_size() {
    cat "$1/size"
}

# Get widget position as "x y"
# Usage: read x y <<< "$(ui_kit_pos path)"
ui_kit_pos() {
    cat "$1/pos"
}

# Set widget position
# Usage: ui_kit_set_pos path x y
ui_kit_set_pos() {
    echo "$2 $3" > "$1/pos"
}

# Set widget size
# Usage: ui_kit_set_size path w h
ui_kit_set_size() {
    echo "$2 $3" > "$1/size"
}

# Get widget absolute position (by summing positions up to root)
# Usage: read ax ay <<< "$(ui_kit_abs_pos path)"
ui_kit_abs_pos() {
    local path="$1"
    local files="" p="$path"

    # Build list of pos files from widget up to root
    while [[ -f "$p/pos" ]]; do
        files="$p/pos $files"
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
    for wtype in $(<"$path/type"); do
        if type "ui_widget_${wtype}_event" &>/dev/null; then
            "ui_widget_${wtype}_event" "$path" "$event" "$@" && return 0
        fi
    done

    # Bubble to parent
    parent=$(dirname "$path")
    [[ "$parent" != "$path" && -f "$parent/type" ]] && ui_event "$parent" "$event" "$@"
}

#
# Focus management
#

# Get currently focused widget path
# Usage: focused=$(ui_kit_get_focus)
ui_kit_get_focus() {
    cat "$_UI_KIT_ROOT/focused"
}

# Check if a widget has focus
# Usage: ui_kit_has_focus path && echo "focused"
ui_kit_has_focus() {
    [[ "$(<"$_UI_KIT_ROOT/focused")" == "$1" ]]
}

# Set focus to a widget (sends focus:out/focus:in events, marks both dirty)
# Usage: ui_kit_set_focus target
ui_kit_set_focus() {
    local target="$1"
    local current

    current=$(<"$_UI_KIT_ROOT/focused")

    # Send focus:out to current and mark dirty
    if [[ -n "$current" && -d "$current" ]]; then
        ui_event "$current" "focus:out"
        ui_kit_dirty "$current"
    fi

    # Update focus
    echo "$target" > "$_UI_KIT_ROOT/focused"

    # Send focus:in to new target and mark dirty
    if [[ -n "$target" && -d "$target" ]]; then
        ui_event "$target" "focus:in"
        ui_kit_dirty "$target"
    fi
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
# Usage: ui_kit_render
ui_kit_render() {
    local manifest script_dir
    manifest=$(mktemp)
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # First pass: redraw any dirty widgets to their buffer files
    ui_kit_walk "$_UI_KIT_ROOT" _ui_kit_redraw_if_dirty

    # Second pass: build manifest of all buffers with absolute positions
    _ui_kit_build_manifest "$_UI_KIT_ROOT" "" > "$manifest"

    # Composite and display (strip tabs for terminal output)
    awk -f "$script_dir/buffer_blit.awk" < "$manifest" | tr -d '\t'

    rm -f "$manifest"
}

# Internal: redraw a widget if dirty
_ui_kit_redraw_if_dirty() {
    local path="$1" depth="$2"
    local wtype

    if ui_kit_is_dirty "$path"; then
        # Call draw function for each trait
        for wtype in $(<"$path/type"); do
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
    buf_file="$path/buffer"

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
# Usage: ui_kit_destroy
ui_kit_destroy() {
    rm -rf "$_UI_KIT_ROOT"
    _UI_KIT_ROOT=""
}

#
# Hit testing
#

# Find the deepest widget at absolute coordinates (respecting clip regions)
# Returns the widget path, or empty if no hit
# Usage: widget=$(ui_kit_hit_test ax ay)
ui_kit_hit_test() {
    local ax="$1" ay="$2"

    _ui_kit_build_manifest "$_UI_KIT_ROOT" "" "" |
        tac |
        awk -v x="$ax" -v y="$ay" '
            x >= $2 && x < $2+$6 && y >= $3 && y < $3+$7 {
                sub(/\/buffer$/, "", $1)
                print $1
            }
        '
}

#
# Terminal setup and input
#

# Initialize terminal for UI (call once at start)
# Usage: ui_kit_init_term
ui_kit_init_term() {
    # Hide cursor
    printf '\e[?25l'
    # Enable mouse reporting (SGR extended mode)
    printf '\e[?1000h\e[?1006h'
    # Enable raw mode
    stty -echo -icanon
}

# Cleanup terminal (call on exit via trap)
# Usage: trap ui_kit_cleanup EXIT
ui_kit_cleanup() {
    # Disable mouse reporting
    printf '\e[?1006l\e[?1000l'
    # Show cursor
    printf '\e[?25h'
    # Restore terminal
    stty echo icanon
}

# Read and parse terminal input
# Outputs: "event arg1 arg2 ..." or empty for unknown
# Usage: read -r event args <<< "$(ui_kit_read_input)"
ui_kit_read_input() {
    local c
    IFS= read -rsn1 -d '' c

    case "$c" in
        $'\e') _ui_kit_read_escape ;;
        $'\x01') echo "key ctrl+a" ;;
        $'\x02') echo "key ctrl+b" ;;
        $'\x03') echo "key ctrl+c" ;;
        $'\x04') echo "key ctrl+d" ;;
        $'\x05') echo "key ctrl+e" ;;
        $'\x06') echo "key ctrl+f" ;;
        $'\x07') echo "key ctrl+g" ;;
        $'\x08') echo "key backspace" ;;
        $'\x09') echo "key tab" ;;
        $'\x0a') echo "key enter" ;;
        $'\x0b') echo "key ctrl+k" ;;
        $'\x0c') echo "key ctrl+l" ;;
        $'\x0d') echo "key enter" ;;
        $'\x0e') echo "key ctrl+n" ;;
        $'\x0f') echo "key ctrl+o" ;;
        $'\x10') echo "key ctrl+p" ;;
        $'\x11') echo "key ctrl+q" ;;
        $'\x12') echo "key ctrl+r" ;;
        $'\x13') echo "key ctrl+s" ;;
        $'\x14') echo "key ctrl+t" ;;
        $'\x15') echo "key ctrl+u" ;;
        $'\x16') echo "key ctrl+v" ;;
        $'\x17') echo "key ctrl+w" ;;
        $'\x18') echo "key ctrl+x" ;;
        $'\x19') echo "key ctrl+y" ;;
        $'\x1a') echo "key ctrl+z" ;;
        $'\x7f') echo "key backspace" ;;
        '') echo "key ctrl+space" ;;
        ' ') echo "key space" ;;
        *) echo "key $c" ;;
    esac
}

# Internal: parse escape sequences
_ui_kit_read_escape() {
    local c seq=""

    # Try to read next char with timeout
    IFS= read -rsn1 -t 0.01 c || { echo "key esc"; return; }

    case "$c" in
        '[')
            # CSI sequence - read until letter or ~
            while IFS= read -rsn1 -t 0.01 c; do
                seq+="$c"
                [[ "$c" =~ [A-Za-z~] ]] && break
            done
            _ui_kit_parse_csi "$seq"
            ;;
        'O')
            # SS3 sequence (F1-F4)
            IFS= read -rsn1 -t 0.01 c
            case "$c" in
                P) echo "key f1" ;;
                Q) echo "key f2" ;;
                R) echo "key f3" ;;
                S) echo "key f4" ;;
            esac
            ;;
        *)
            # Alt+key
            echo "key alt+$c"
            ;;
    esac
}

# Internal: parse CSI sequences
_ui_kit_parse_csi() {
    local seq="$1"

    case "$seq" in
        # Basic keys
        A) echo "key up" ;;
        B) echo "key down" ;;
        C) echo "key right" ;;
        D) echo "key left" ;;
        H) echo "key home" ;;
        F) echo "key end" ;;
        Z) echo "key shift+tab" ;;
        3~) echo "key delete" ;;
        5~) echo "key pageup" ;;
        6~) echo "key pagedown" ;;
        15~) echo "key f5" ;;
        17~) echo "key f6" ;;
        18~) echo "key f7" ;;
        19~) echo "key f8" ;;
        20~) echo "key f9" ;;
        21~) echo "key f10" ;;
        23~) echo "key f11" ;;
        24~) echo "key f12" ;;
        # Modified keys: 1;{mod}{key}
        1\;[2-8][ABCDHF])
            _ui_kit_parse_modified_key "$seq"
            ;;
        '<'*)
            # SGR mouse: <btn;x;y;M or <btn;x;y;m
            _ui_kit_parse_mouse "${seq:1}"
            ;;
    esac
    # Unknown sequences ignored
}

# Internal: parse modified keys like 1;2A (shift+up)
# Modifier codes: 2=shift, 3=alt, 4=shift+alt, 5=ctrl, 6=ctrl+shift, 7=ctrl+alt, 8=ctrl+shift+alt
_ui_kit_parse_modified_key() {
    local seq="$1"
    local mod="${seq:2:1}"
    local key="${seq:3:1}"
    local prefix="" keyname=""

    # Build modifier prefix
    case "$mod" in
        2) prefix="shift+" ;;
        3) prefix="alt+" ;;
        4) prefix="shift+alt+" ;;
        5) prefix="ctrl+" ;;
        6) prefix="ctrl+shift+" ;;
        7) prefix="ctrl+alt+" ;;
        8) prefix="ctrl+shift+alt+" ;;
    esac

    # Decode key
    case "$key" in
        A) keyname="up" ;;
        B) keyname="down" ;;
        C) keyname="right" ;;
        D) keyname="left" ;;
        H) keyname="home" ;;
        F) keyname="end" ;;
    esac

    [[ -n "$keyname" ]] && echo "key ${prefix}${keyname}"
}

# Internal: parse SGR mouse sequences
_ui_kit_parse_mouse() {
    local seq="$1"
    local btn x y suffix

    # Parse btn;x;y from sequence (strip trailing M/m)
    IFS=';' read -r btn x y <<< "${seq%[Mm]}"
    suffix="${seq: -1}"

    # Convert to 0-indexed
    ((x--)); ((y--))

    # Check for scroll (bit 6 set)
    if [[ $((btn & 64)) -ne 0 ]]; then
        if [[ $((btn & 1)) -eq 0 ]]; then
            echo "mouse:scroll up $x $y"
        else
            echo "mouse:scroll down $x $y"
        fi
        return
    fi

    # Decode button (bits 0-1)
    local button
    case $((btn & 3)) in
        0) button="left" ;;
        1) button="middle" ;;
        2) button="right" ;;
        *) return ;;
    esac

    # Press or release
    if [[ "$suffix" == "M" ]]; then
        echo "mouse:down $button $x $y"
    else
        echo "mouse:up $button $x $y"
    fi
}
