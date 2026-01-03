#!/usr/bin/env bash
source scrip/libs.sh

# App-level event handler - receives bubbled events
ui_widget_app_event() {
    local path="$1" event="$2"
    shift 2
    case "$event" in
        key)
            [[ "$1" == "q" ]] && ui_kit_quit && return 0
            ;;
        press)
            ui_kit_quit
            return 0
            ;;
    esac
    return 1
}

# Create root with app trait to receive bubbled events
ui_kit_init
echo "app root" > "$_UI_KIT_ROOT/type"

# Create list on the left (most of the screen)
read term_w term_h < "$_UI_KIT_ROOT/size"
list_w=$((term_w - 20))
list=$(for i in $(seq 1 1000); do printf "Item %03d - Test entry\n" "$i"; done |
       ui_widget_list "$_UI_KIT_ROOT" 1 1 "$list_w" $((term_h - 2)))

# Create exit button on the right
btn=$(ui_widget_button "$_UI_KIT_ROOT" "Exit" $((term_w - 16)) 2 12 3)

# Start with list focused
ui_kit_set_focus "$list"

# Run the UI
ui_kit_run
