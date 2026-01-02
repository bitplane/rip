#!/usr/bin/env bash
source scrip/libs.sh

ui_kit_init_term
trap ui_kit_cleanup EXIT

echo "Press keys, click mouse, scroll. Press 'q' to quit." >&2
echo "" >&2

while true; do
    input=$(ui_kit_read_input)
    echo "$input"
    
    # Quit on 'q'
    [[ "$input" == "key q" ]] && break
done
