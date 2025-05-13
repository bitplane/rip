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
ui_widget_buffer_new() {
    awk -v w="$1" -v h="$1" 'BEGIN{for(i=0;i<h;i++){for(j=1;j<w;j++)printf("\t"); print ""}}'
}

# Inserts one buffer into another
# Usage: bg_file fg_file fg_x fg_y fg_offset_x fg_offset_y fg_width fg_height
ui_widget_buffer_insert() {
  local bg="$1" fg="$2" xpos="$3" ypos="$4" xoff="$5" yoff="$6" width="$7" height="$8"
  awk -v xpos="$xpos" -v ypos="$ypos" -v xoff="$xoff" -v yoff="$yoff" -v width="$width" -v height="$height" '
    BEGIN { FS = OFS = "\t" }
    FNR==NR { fg[NR] = $0; next }
    {
      row = FNR
      if (row >= ypos + 1 && row <= ypos + height) {
        fi = yoff + row - (ypos + 1); split(fg[fi + 1], f); split($0, b)
        for (i = 1; i <= length(b); i++) {
          if (i > xpos && i <= xpos + width) {
            idx = i - xpos + xoff; b[i] = (idx <= length(f)) ? f[idx] : " ";
          }
        }
        for (i = 1; i <= length(b); i++)
          printf "%s%s", b[i], (i < length(b) ? OFS : ORS)
      } else { print }
    }' "$fg" "$bg"
}


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

# Create a string of text for the UI
# Usage: ui_text "text" [escapes]
ui_widget_buffer_text() {
  awk -v text="$1" -v s="$2" -v r=$'\033[0m' '
    BEGIN {
      n = split(text, chars, "")
      printf "%s", s
      for (i = 1; i <= n; i++) { printf "%s", chars[i]; if (i < n) printf "\t"}
      printf "%s\n", r
    }'
}

