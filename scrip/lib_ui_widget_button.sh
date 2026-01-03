#!/usr/bin/env bash

#
# Button widget trait
#
# Usage: btn=$(ui_widget_button parent "Label" x y w h)
#
# Traits: button focusable
# Properties: label
# Events: emits "press" on click/enter/space
#

# Create a button widget
ui_widget_button() {
    local parent="$1" label="$2" x="$3" y="$4" w="$5" h="$6"
    local path

    path=$(ui_kit_add "$parent" "button focusable" "$x" "$y" "$w" "$h")
    echo "$label" > "$path/label"
    echo "$path"
}

# Draw the button
ui_widget_button_draw() {
    local path="$1"
    local w h label bg fg style

    read w h < "$path/size"
    label=$(<"$path/label")

    if ui_kit_has_focus "$path"; then
        bg=$'\e[44m'  # blue bg
    else
        bg=$'\e[100m' # gray bg
    fi
    fg=$'\e[97m'  # white text
    style="${bg}${fg}"

    # Build lines: blank rows, then centered label row, then blank rows
    local label_row=$((h / 2))
    local pad=$(( (w - ${#label}) / 2 ))

    for ((row = 0; row < h; row++)); do
        if ((row == label_row)); then
            printf "%*s%s%*s\n" "$pad" "" "$label" "$((w - pad - ${#label}))" ""
        else
            printf "%*s\n" "$w" ""
        fi
    done | ui_kit_blit_text_file /dev/stdin "$w" "$style" > "$path/buffer"
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
