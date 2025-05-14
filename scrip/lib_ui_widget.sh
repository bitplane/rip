#!/usr/bin/env bash


#
# ui widgets
#
# * let's rename this to `kit`
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
#  * a kit widget has w h        <- width and height
#  * its parent has: kid x y w h <- clip region
#  for k in kids:
#    kids.ctime kid.ctime clip
#  
# Adds a widget to the ui graph
# Usage: path=$(ui_widget_add parent type x y w h)
ui_widget_add() {
    local parent="$1" t="$2" x="$3" y="$4" w="$5" h="$6" path
    path="$(find "$parent" -type d -maxdepth 1 -mindepth 1 | wc -l)"
    mkdir -p "$path"
    echo "$t"                              | meta_set "ui.type"   0 "$path"
    echo "$parent"                         | meta_set "ui.parent" 0 "$path"
    printf "$x\n$y\n"                      | meta_set "ui.pos"    0 "$path"
    printf "$w\n$h\n"                      | meta_set "ui.size"   0 "$path"
    printf "0\n0\n$w\n$h\n"                | meta_set "ui.clip"   0 "$path"
    ui_widget_buffer_new "$w" "$h" "$path" | meta_set "ui.buffer" 0 "$path"
    echo "$path"
}

# Draw this widget (callback)
ui_widget_on_draw() {
    local t="$(meta_get "ui.type" 0 "$1")"
    echo $t $1
    "ui_widget_on_draw_$t" "$1"
    #for child in $(find "$1" -type d -maxdepth 1); do
    #    ui_widget_draw $child
    #done
}

# Adds a screen widget
# Usage: ui_widget_add_screen
ui_widget_screen_add() {
    local path
    path=$(ui_widget_add "$1" screen 0 0 "$(tput cols)" "$(tput lines)")
    echo $2 | meta_set "$1" "ui.title" 0
}

ui_widget_on_draw_screen() {
    read w h < <(meta_get ui.pos 0 "$1")
    title_bar=$(ui_center_text "$w" "$(meta_get ui.title 0 "$1")")
    ui_widget_buffer_text "$title_bar"
    #ui_widget_buffer_new $((h - 2))
    ui_widget_buffer_text "$title_bar"
}
