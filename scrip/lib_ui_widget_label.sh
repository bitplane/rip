#!/usr/bin/env bash

#
# Label widget - simple text display
#
# Properties:
#   text    the text to display
#   style   optional ANSI style (default: reset)
#

# Create a label widget
# Usage: label=$(ui_widget_label parent "text" x y w [style])
ui_widget_label() {
    local parent="$1" text="$2" x="$3" y="$4" w="$5" style="${6:-}"
    local path

    path=$(ui_kit_add "$parent" "label" "$x" "$y" "$w" 1)
    echo "$text" > "$path/text"
    [[ -n "$style" ]] && echo "$style" > "$path/style"

    echo "$path"
}

# Draw the label
ui_widget_label_draw() {
    local path="$1" w text style

    read w _ < "$path/size"
    text=$(<"$path/text")
    style=$'\e[0m'
    [[ -f "$path/style" ]] && style=$(<"$path/style")

    # Render text padded to width
    printf "%-${w}s" "$text" | ui_kit_blit_text_file /dev/stdin "$w" "$style" > "$path/buffer"
}
