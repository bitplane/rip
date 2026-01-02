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
