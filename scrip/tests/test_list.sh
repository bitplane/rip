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

# Get actual terminal size
term_w=$(tput cols)
term_h=$(tput lines)

# Create items file with 50 items
items_file=$(mktemp)
for i in $(seq 1 50); do
    printf "Item %03d - Test entry\n" "$i"
done > "$items_file"

# Create root with app trait to receive bubbled events
ui_kit_init
echo "app root" | ui_kit_set "$_UI_KIT_ROOT" "type"
echo "0 0" | ui_kit_set "$_UI_KIT_ROOT" "pos"
echo "$term_w $term_h" | ui_kit_set "$_UI_KIT_ROOT" "size"
ui_kit_blit_new "$term_w" "$term_h" $'\e[40m' > "$_UI_KIT_ROOT/buffer"

# Create list on the left (most of the screen)
list_w=$((term_w - 20))
list=$(ui_widget_list "$_UI_KIT_ROOT" "$items_file" 1 1 "$list_w" $((term_h - 2)))

# Create exit button on the right
btn=$(ui_widget_button "$_UI_KIT_ROOT" "Exit" $((term_w - 16)) 2 12 3)

# Start with list focused
ui_kit_set_focus "$list"

ui_kit_init_term
trap 'ui_kit_cleanup; rm -f "$items_file"' EXIT

while true; do
    printf '\e[H'
    ui_kit_render

    input=$(ui_kit_read_input)
    read -r event args <<< "$input"

    case "$event" in
        key)
            [[ "$args" == "q" ]] && break
            focused=$(ui_kit_get_focus)
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
