#!/usr/bin/env bash
source scrip/libs.sh

# App-level event handler - receives bubbled events
_app_exit=0
ui_widget_app_event() {
    local path="$1" event="$2"
    shift 2
    case "$event" in
        press)
            _app_exit=1
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
list=$(for i in $(seq 1 50); do printf "Item %03d - Test entry\n" "$i"; done |
       ui_widget_list "$_UI_KIT_ROOT" 1 1 "$list_w" $((term_h - 2)))

# Create exit button on the right
btn=$(ui_widget_button "$_UI_KIT_ROOT" "Exit" $((term_w - 16)) 2 12 3)

# Start with list focused
ui_kit_set_focus "$list"

ui_kit_init_term
trap 'ui_kit_cleanup' EXIT

while true; do
    printf '\e[H'
    ui_kit_render

    input=$(ui_kit_read_input)
    read -r event args <<< "$input"

    case "$event" in
        key)
            [[ "$args" == "q" ]] && break
            focused=$(<"$_UI_KIT_ROOT/focused")
            [[ -n "$focused" ]] && ui_event "$focused" "key" "$args"
            ;;
        mouse:*)
            read -r btn_name x y <<< "$args"
            widget=$(ui_kit_hit_test "$x" "$y" | head -1)
            [[ -n "$widget" ]] && ui_event "$widget" "$event" $args
            ;;
    esac

    # Check if app received exit signal via bubbled event
    [[ $_app_exit -eq 1 ]] && break
done
