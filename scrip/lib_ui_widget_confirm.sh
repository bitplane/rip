#!/usr/bin/env bash

#
# Confirm dialog widget - Y/N prompt with buttons
#
# Structure:
#   confirm/
#   ├── message     prompt text
#   ├── 0/          Yes button
#   └── 1/          No button (focused by default)
#
# Events:
#   Emits "confirm" when Yes clicked or 'y' pressed
#   Emits "cancel" when No clicked or 'n'/'q'/'esc' pressed
#

# Create a confirm dialog
# Usage: dialog=$(ui_widget_confirm parent "Are you sure?" x y [w])
ui_widget_confirm() {
    local parent="$1" message="$2" x="$3" y="$4" w="${5:-40}"
    local path h=5 btn_w=8 btn_y=3

    path=$(ui_kit_add "$parent" "confirm" "$x" "$y" "$w" "$h")
    echo "$message" > "$path/message"

    # Create Yes and No buttons
    local yes_x=2
    local no_x=$((w - btn_w - 2))
    ui_widget_button "$path" "Yes" "$yes_x" "$btn_y" "$btn_w" 1 > /dev/null
    ui_widget_button "$path" "No" "$no_x" "$btn_y" "$btn_w" 1 > /dev/null

    # Focus No button by default (safe for deletions)
    ui_kit_set_focus "$path/1"

    echo "$path"
}

# Draw the dialog box with message
ui_widget_confirm_draw() {
    local path="$1" w h message
    read w h < "$path/size"
    message=$(<"$path/message")

    # Draw box background with border and centered message
    awk -v w="$w" -v h="$h" -v msg="$message" '
    BEGIN {
        bg = "\033[100m"  # gray background
        fg = "\033[97m"   # white text
        border = "\033[90m"  # dark gray border
        reset = "\033[0m"

        msg_x = int((w - length(msg)) / 2)
        if (msg_x < 1) msg_x = 1

        for (row = 0; row < h; row++) {
            for (col = 0; col < w; col++) {
                # Border on edges
                if (row == 0 || row == h-1 || col == 0 || col == w-1) {
                    printf "%s ", border
                }
                # Message on row 1
                else if (row == 1 && col >= msg_x && col < msg_x + length(msg)) {
                    c = substr(msg, col - msg_x + 1, 1)
                    printf "%s%s%s", bg, fg, c
                }
                # Background
                else {
                    printf "%s ", bg
                }
                if (col < w - 1) printf "\t"
            }
            if (row < h - 1) print ""
        }
    }' > "$path/buffer"
}

# Handle dialog events
ui_widget_confirm_event() {
    local path="$1" event="$2"
    shift 2

    case "$event" in
        key)
            case "$1" in
                y|Y)
                    ui_event "$path" "confirm"
                    return 0
                    ;;
                n|N|q|esc)
                    ui_event "$path" "cancel"
                    return 0
                    ;;
            esac
            ;;
        press)
            # Button was pressed - check which one by seeing who has focus
            local focused=$(<"$_UI_KIT_ROOT/focused")
            if [[ "$focused" == "$path/0" ]]; then
                ui_event "$path" "confirm"
            else
                ui_event "$path" "cancel"
            fi
            return 0
            ;;
    esac
    return 1
}
