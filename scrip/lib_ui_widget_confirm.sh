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

    local bg=$'\e[100m'  # gray background
    local fg=$'\e[97m'   # white text

    local msg_pad=$(( (w - 2 - ${#message}) / 2 ))
    ((msg_pad < 0)) && msg_pad=0

    # Build lines for the dialog box
    for ((row = 0; row < h; row++)); do
        if ((row == 0 || row == h - 1)); then
            # Top/bottom border
            printf "%*s\n" "$w" ""
        elif ((row == 1)); then
            # Message row: padding + message + padding
            printf " %*s%s%*s \n" "$msg_pad" "" "$message" "$((w - 2 - msg_pad - ${#message}))" ""
        else
            # Interior row
            printf " %*s \n" "$((w - 2))" ""
        fi
    done | ui_kit_blit_text_file /dev/stdin "$w" "${bg}${fg}" > "$path/buffer"
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
                left)
                    ui_kit_set_focus "$path/0"  # Yes button
                    return 0
                    ;;
                right)
                    ui_kit_set_focus "$path/1"  # No button
                    return 0
                    ;;
                enter|space)
                    # Activate focused button
                    local focused=$(<"$_UI_KIT_ROOT/focused")
                    if [[ "$focused" == "$path/0" ]]; then
                        ui_event "$path" "confirm"
                    else
                        ui_event "$path" "cancel"
                    fi
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
