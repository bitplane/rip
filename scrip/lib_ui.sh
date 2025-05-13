#!/usr/bin/env bash
# Zero width space to stop chars from taking up too much space
ZWS=$'\u200B'
EMOJIS="💽$ZWS📄$ZWSℹ️$ZWS📦$ZWS🌍$ZWS✅$ZWS"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

show_latest_line() {
    local pre="$1"
    echo
    while IFS= read -r line; do
        printf "\033[A\033[2K%s\n" "${pre}$line"
    done
    echo
}

# Gets the emoji for a work dir
# Usage: ui_emoji ["path"] 
ui_emoji() {
  local dir="${1:-.}"
  local base=$(basename "$dir")

  # Skip dirs get 
  if [[ $base =~ \.skip$ ]]; then
    echo "❌$ZWS"
    return
  fi

  # Check if the directory is a numbered stage or under a stage
  if [[ $base =~ ^[1-5]\. ]]; then
      local pos=$(( ${base:0:1} * 2))
      echo "${EMOJIS:$pos:2}"
  else
    echo "  "
  fi
}

# Clears a widget's buffer



# Adds a widget to the ui graph
# Usage: ui_widget_add type name x y w h
ui_widget_add() {
    local t=$1 parent="$7" path="$7/$2" x="$3" y="$4" w="$5" h="$6"
    mkdir -p "$path"
    echo "$t"               | meta_set "ui.type"   0 "$path"
    echo "$parent"          | meta_set "ui.parent" 0 "$path"
    printf "$x\n$y\n"       | meta_set "ui.pos"    0 "$path"
    printf "$w\n$h\n"       | meta_set "ui.size"   0 "$path"
    printf "0\n0\n$w\n$h\n" | meta_set "ui.clip"   0 "$path"
    ui_widget_buffer_new "$w" "$h" "$path"
}

# Draw this widget
# Usage: ui_widget_draw path
ui_widgeit_draw() {
    t < <(meta_get ui.type 0 $1)
    "ui_widget_draw_$t" $1
    for child in ${1}/*; do
        ui_widget_draw $child
    done
}

ui_widget_draw_screen() {
    read w h < <(meta_get ui.pos 0 "$1")
    ui_center_text $w "$(meta_get ui.title 0 "$1")" | meta_set "ui.buffer" 0 "$1"
}




