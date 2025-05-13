#!/usr/bin/env bash

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
