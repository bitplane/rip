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
# Note: Uses bash to handle UTF-8 characters properly
ui_kit_blit_text_file() {
    local file="$1" width="$2" style="${3:-\033[0m}"
    local line i char
    while IFS= read -r line || [[ -n "$line" ]]; do
        for ((i = 0; i < width; i++)); do
            char="${line:i:1}"
            [[ -z "$char" ]] && char=" "
            printf "%s%s" "$style$char" $'\t'
        done
        # Remove trailing tab and add newline
        printf "\b \n"
    done < "$file"
}
