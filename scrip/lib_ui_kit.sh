#!/usr/bin/env bash


#
# ui widget kit
#
# render pipeline:
# 1. start at some viewport, which has a buffer
#
# example:
#    screen
#        title         0 0 w h     # clip
#        *grid         1 2 w/2 h-4
#            column1   0     w/3 
#            column2   w/3+1 
#            column3
#        footer
#        info
#            *animated
#
# 
# ui.clip x y w h
# ui.pos  x y w h




# Adds a widget to the ui graph
# Usage: path=$(ui_kit_add parent type x y w h)
ui_kit_add() {
    local parent="$1" t="$2" x="$3" y="$4" w="$5" h="$6" path
    path="$(find "$parent" -type d -maxdepth 1 -mindepth 1 | wc -l)"
    mkdir -p "$path"
    echo "$t"                 | meta_set "ui.type"   0 "$path"
    echo "$parent"            | meta_set "ui.parent" 0 "$path"
    printf "$x\n$y\n"         | meta_set "ui.pos"    0 "$path"
    printf "$w\n$h\n"         | meta_set "ui.size"   0 "$path"
    printf "0\n0\n$w\n$h\n"   | meta_set "ui.clip"   0 "$path"
    ui_kit_blit_new "$w" "$h" | meta_set "ui.buffer" 0 "$path"
    echo "$path"
}

# Starting at the given widget, find all clip regions and positions
# 
#ui_kit_clip_list() {
#
#}

ui_kit_on_draw() {
    local t="$(meta_get "ui.type" 0 "$1")"
    echo $t $1
    "ui_kit_on_draw_$t" "$1"
    #for child in $(find "$1" -type d -maxdepth 1); do
    #    ui_kit_on_draw $child
    #done
}

# Add the screen
ui_kit_add_screen() {
    local path
    path=$(ui_kit_add "$1" screen 0 0 "$(tput cols)" "$(tput lines)")
    echo $2 | meta_set "$1" "ui.title" 0
}



ui_kit_on_draw_screen() {
    read w h < <(meta_get ui.pos 0 "$1")
    title_bar=$(ui_center_text "$w" "$(meta_get ui.title 0 "$1")")
    ui_kit_blit_text "$title_bar"
    #ui_kit_blit_new $((h - 2))
    ui_kit_blit_text "$title_bar"
}
