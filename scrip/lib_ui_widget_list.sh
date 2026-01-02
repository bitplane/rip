#!/usr/bin/env bash

#
# List widget - scrollable, selectable list
#
# Structure:
#   list/           (container with "list focusable" traits)
#   ├── 0/          (text content - tall buffer that scrolls)
#   └── 1/          (selection highlight - single row)
#
# Properties:
#   items           path to text file with items (newline-delimited)
#   selected        selected index (0-based)
#   scroll          scroll offset
#   item_count      total number of items
#

# Create a list widget
# Usage: list=$(ui_widget_list parent items_file x y w h)
ui_widget_list() {
    local parent="$1" items="$2" x="$3" y="$4" w="$5" h="$6"
    local path item_count

    # Create container
    path=$(ui_kit_add "$parent" "list focusable" "$x" "$y" "$w" "$h")

    # Store items file path and count
    echo "$items" > "$path/items"
    item_count=$(wc -l < "$items")
    echo "$item_count" > "$path/item_count"
    echo "0" > "$path/selected"
    echo "0" > "$path/scroll"

    # Create text content child (will be sized in draw)
    ui_kit_add "$path" "text" 0 0 "$w" "$item_count" > /dev/null

    # Create selection highlight child (single row)
    ui_kit_add "$path" "selection" 0 0 "$w" 1 > /dev/null

    echo "$path"
}

# Draw the list
ui_widget_list_draw() {
    local path="$1"
    local w h items selected scroll item_count
    local text_path sel_path

    read w h < "$path/size"
    items=$(<"$path/items")
    selected=$(<"$path/selected")
    scroll=$(<"$path/scroll")
    item_count=$(<"$path/item_count")

    text_path="$path/0"
    sel_path="$path/1"

    # Rebuild text buffer from items file
    ui_kit_blit_text_file "$items" "$w" $'\e[0m' > "$text_path/buffer"

    # Update text widget size and position (scrolls with offset)
    echo "$w $item_count" > "$text_path/size"
    echo "0 -$scroll" > "$text_path/pos"

    # Position selection highlight at visible row - extract the selected line with highlight style
    local sel_visible=$((selected - scroll))
    local sel_style=$'\e[100m'  # grey when unfocused
    ui_kit_has_focus "$path" && sel_style=$'\e[44m'  # blue when focused
    sed -n "$((selected + 1))p" "$items" | ui_kit_blit_text_file /dev/stdin "$w" "$sel_style" > "$sel_path/buffer"
    echo "0 $sel_visible" > "$sel_path/pos"

    # Clear the container buffer (transparent)
    ui_kit_blit_new "$w" "$h" $'\e[0m' > "$path/buffer"
}

# Handle list events
ui_widget_list_event() {
    local path="$1" event="$2"
    shift 2

    local selected scroll item_count h
    selected=$(<"$path/selected")
    scroll=$(<"$path/scroll")
    item_count=$(<"$path/item_count")
    read _ h < "$path/size"

    case "$event" in
        key)
            local key="$1"
            case "$key" in
                up)
                    _ui_widget_list_select "$path" $((selected - 1))
                    return 0
                    ;;
                down)
                    _ui_widget_list_select "$path" $((selected + 1))
                    return 0
                    ;;
                pageup)
                    _ui_widget_list_select "$path" $((selected - h))
                    return 0
                    ;;
                pagedown)
                    _ui_widget_list_select "$path" $((selected + h))
                    return 0
                    ;;
                home)
                    _ui_widget_list_select "$path" 0
                    return 0
                    ;;
                end)
                    _ui_widget_list_select "$path" $((item_count - 1))
                    return 0
                    ;;
                enter)
                    ui_event "$path" "activate" "$selected"
                    return 0
                    ;;
            esac
            ;;
        mouse:down)
            local btn="$1" mx="$2" my="$3"
            if [[ "$btn" == "left" ]]; then
                # Convert click to item index
                local rel_y=$((my - $(ui_kit_abs_pos "$path" | cut -d' ' -f2)))
                local clicked=$((scroll + rel_y))
                _ui_widget_list_select "$path" "$clicked"
                ui_kit_set_focus "$path"
                return 0
            fi
            ;;
        mouse:scroll)
            local dir="$1"
            if [[ "$dir" == "up" ]]; then
                _ui_widget_list_scroll "$path" $((scroll - 3))
            else
                _ui_widget_list_scroll "$path" $((scroll + 3))
            fi
            return 0
            ;;
    esac
    return 1
}

# Internal: select an item and adjust scroll
_ui_widget_list_select() {
    local path="$1" new_sel="$2"
    local item_count scroll h

    item_count=$(<"$path/item_count")
    scroll=$(<"$path/scroll")
    read _ h < "$path/size"

    # Clamp selection
    [[ $new_sel -lt 0 ]] && new_sel=0
    [[ $new_sel -ge $item_count ]] && new_sel=$((item_count - 1))

    # Adjust scroll to keep selection visible
    if [[ $new_sel -lt $scroll ]]; then
        scroll=$new_sel
    elif [[ $new_sel -ge $((scroll + h)) ]]; then
        scroll=$((new_sel - h + 1))
    fi

    # Update state
    echo "$new_sel" > "$path/selected"
    echo "$scroll" > "$path/scroll"
    ui_kit_dirty "$path"

    # Emit select event
    ui_event "$path" "select" "$new_sel"
}

# Internal: scroll without changing selection
_ui_widget_list_scroll() {
    local path="$1" new_scroll="$2"
    local item_count h

    item_count=$(<"$path/item_count")
    read _ h < "$path/size"

    # Clamp scroll
    [[ $new_scroll -lt 0 ]] && new_scroll=0
    local max_scroll=$((item_count - h))
    [[ $max_scroll -lt 0 ]] && max_scroll=0
    [[ $new_scroll -gt $max_scroll ]] && new_scroll=$max_scroll

    echo "$new_scroll" > "$path/scroll"
    ui_kit_dirty "$path"
}
