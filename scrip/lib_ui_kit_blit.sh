#!/usr/bin/env bash

#
# Buffer creation for UI kit
#

# Creates a new character buffer (tab-delimited cells)
# Usage: ui_kit_blit_new width height [style]
ui_kit_blit_new() {
    awk -v w="$1" -v h="$2" -v s="${3:-\033[0m}" 'BEGIN{
        for(i=1;i<=h;i++){
            for(j=1;j<=w;j++)printf "%s %s", s, j<w?"\t":""
            if(i<h)print""
        }
    }'
}

# Convert a text file to a buffer (one line per row)
# Usage: ui_kit_blit_text_file file width [style]
ui_kit_blit_text_file() {
    local file="$1" width="$2" style="${3:-\033[0m}"
    awk -v s="$style" -v w="$width" '
    {
        for (i = 1; i <= w; i++) {
            c = (i <= length($0)) ? substr($0, i, 1) : " "
            printf "%s%s%s", s, c, (i < w ? "\t" : "")
        }
        print ""
    }' "$file"
}
