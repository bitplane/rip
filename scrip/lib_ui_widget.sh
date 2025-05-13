#!/usr/bin/env bash

# Adds a widget to the ui graph
# Usage: ui_widget_add type name x y w h [parent]
ui_widget_add() {
    local t=$1 parent="$7" path="${7:-}/$2" x="$3" y="$4" w="$5" h="$6"
    mkdir -p "$path"
    echo "$t"                              | meta_set "ui.type"   0 "$path"
    echo "$parent"                         | meta_set "ui.parent" 0 "$path"
    printf "$x\n$y\n"                      | meta_set "ui.pos"    0 "$path"
    printf "$w\n$h\n"                      | meta_set "ui.size"   0 "$path"
    printf "0\n0\n$w\n$h\n"                | meta_set "ui.clip"   0 "$path"
    ui_widget_buffer_new "$w" "$h" "$path" | meta_set "ui.buffer" 0 "$path"
}

# Draw this widget
# Usage: ui_widget_draw path
ui_widget_draw() {
    local t="$(meta_get "ui.type" 0 "$1")"
    "ui_widget_draw_$t" "$1"
    for child in $(find "$1" -type d -maxdepth 1); do
        ui_widget_draw $child
    done
}

ui_widget_draw_screen() {
    read w h < <(meta_get ui.pos 0 "$1")
    title_bar=$(ui_center_text $w "$(meta_get ui.title 0 "$1")")
    ui_widget_buffer_text "$title_bar"
    ui_widget_buffer_new $((h - 2))
    ui_widget_buffer_text "$title_bar"
}
