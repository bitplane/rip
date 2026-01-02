#!/usr/bin/env bash

#
# Button widget trait
#
# Usage: btn=$(ui_widget_button parent "Label" x y w h)
#
# Traits: button focusable
# Properties: ui.label
# Events: emits "press" on click/enter/space
#

# Create a button widget
ui_widget_button() {
    local parent="$1" label="$2" x="$3" y="$4" w="$5" h="$6"
    local path

    path=$(ui_kit_add "$parent" "button focusable" "$x" "$y" "$w" "$h")
    echo "$label" | ui_kit_set "$path" "label"
    echo "$path"
}

# Draw the button
ui_widget_button_draw() {
    local path="$1"
    local w h label bg fg

    read w h <<< "$(ui_kit_size "$path")"
    label=$(ui_kit_get "$path" "label")

    if ui_kit_has_focus "$path"; then
        bg=$'\e[44m'  # blue bg
    else
        bg=$'\e[100m' # gray bg
    fi
    fg=$'\e[97m'  # white text

    # Build buffer with centered text
    awk -v w="$w" -v h="$h" -v label="$label" -v bg="$bg" -v fg="$fg" '
    BEGIN {
        len = length(label)
        px = int((w - len) / 2)
        py = int(h / 2)

        for (row = 0; row < h; row++) {
            for (col = 0; col < w; col++) {
                if (row == py && col >= px && col < px + len) {
                    c = substr(label, col - px + 1, 1)
                    printf "%s%s%s", bg, fg, c
                } else {
                    printf "%s ", bg
                }
                if (col < w - 1) printf "\t"
            }
            if (row < h - 1) print ""
        }
    }' | meta_set "ui.buffer" 0 "$path"
}

# Handle button events
ui_widget_button_event() {
    local path="$1" event="$2"
    shift 2

    case "$event" in
        key)
            local key="$1"
            case "$key" in
                enter|space)
                    ui_event "$path" "press"
                    return 0
                    ;;
            esac
            ;;
        mouse:down)
            local btn="$1"
            if [[ "$btn" == "left" ]]; then
                ui_kit_set_focus "$path"
                ui_event "$path" "press"
                return 0
            fi
            ;;
    esac
    return 1
}
