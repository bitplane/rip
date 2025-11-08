#!/usr/bin/env bash
#
# Minimal widget library for TUI apps
# Focused on the components actually needed by dip.sh
#

# Screen state
declare -g _UI_SCREEN_W _UI_SCREEN_H
declare -g _UI_BUFFER  # Current screen buffer (file path)

#
# Screen management
#

ui_screen_init() {
    _UI_SCREEN_W=$(tput cols)
    _UI_SCREEN_H=$(tput lines)
    _UI_BUFFER=$(mktemp)

    # Enter alternate screen
    tput smcup
    tput civis
    clear
}

ui_screen_cleanup() {
    rm -f "$_UI_BUFFER" 2>/dev/null
    tput rmcup
    tput cnorm
}

ui_screen_render() {
    tput cup 0 0
    cat "$_UI_BUFFER"
}

#
# Text line widget
#

# Renders a single line of text with optional styling
# Usage: ui_text "content" [bold] [reverse] [color]
ui_text() {
    local text="$1" bold="$2" reverse="$3" color="$4"

    [[ "$bold" == "1" ]] && tput bold
    [[ "$reverse" == "1" ]] && tput rev
    [[ -n "$color" ]] && tput setaf "$color"

    printf "%s\r\n" "$text"

    tput sgr0
}

#
# List widget
#

# Render a scrollable list with selection
# Usage: ui_list entries_array cursor_idx visible_rows render_callback
ui_list() {
    local -n entries=$1
    local cursor=$2
    local visible=$3
    local callback=$4

    local total=${#entries[@]}

    # Calculate scroll offset
    local start=0
    if [[ $total -gt $visible ]]; then
        local half=$((visible / 2))

        if [[ $cursor -ge $half ]]; then
            start=$((cursor - half))
        fi

        if [[ $((start + visible)) -gt $total ]]; then
            start=$((total - visible))
        fi
    fi

    # Render visible entries
    local end=$((start + visible))
    [[ $end -gt $total ]] && end=$total

    for ((i=start; i<end; i++)); do
        local selected=0
        [[ $i -eq $cursor ]] && selected=1

        # Call the render callback for this entry
        $callback "$selected" "$i" "${entries[$i]}"
    done
}

#
# Layout helpers
#

# Position cursor at line N
ui_line() {
    tput cup "$1" 0
}

# Clear current line
ui_clear_line() {
    tput el
}
