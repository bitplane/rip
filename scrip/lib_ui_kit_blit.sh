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
# Uses grep -o for UTF-8 safe character splitting
ui_kit_blit_text_file() {
    local file="$1" width="$2" style="${3:-}"
    [[ -z "$style" ]] && style=$'\e[0m'
    local RS=$'\x1E'  # ASCII record separator as line marker

    # Pad lines to width, split UTF-8 chars, add style, join with tabs
    awk -v w="$width" '{printf "%-*s\n", w, $0}' "$file" |
        sed "s/$/$RS/" |
        grep -o ".\|$RS" |
        sed "/^$RS\$/!s|^|$style|" |
        paste -sd'	' |
        sed "s/$RS	/\n/g; s/$RS\$//"
}
