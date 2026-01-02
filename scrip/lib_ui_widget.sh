#!/usr/bin/env bash

#
# Base widget traits
#

# focusable - marks widget as able to receive focus
# Focus state is checked via ui_kit_has_focus, not stored per-widget
ui_widget_focusable_event() {
    local path="$1" event="$2"
    case "$event" in
        focus:in|focus:out)
            return 0
            ;;
    esac
    return 1
}

# root - handles tab/shift+tab focus cycling
ui_widget_root_event() {
    local path="$1" event="$2"
    shift 2

    case "$event" in
        key)
            local key="$1"
            case "$key" in
                tab)
                    _ui_widget_root_cycle_focus 1
                    return 0
                    ;;
                shift+tab)
                    _ui_widget_root_cycle_focus -1
                    return 0
                    ;;
            esac
            ;;
    esac
    return 1
}

# Internal: cycle focus through focusable widgets
# Args: direction (1=forward, -1=backward)
_ui_widget_root_cycle_focus() {
    local dir="$1"
    local focusables=()
    local current idx

    # Gather all focusable widgets
    while IFS= read -r widget; do
        focusables+=("$widget")
    done < <(_ui_widget_root_find_focusables "$_UI_KIT_ROOT")

    [[ ${#focusables[@]} -eq 0 ]] && return

    # Find current focus index
    current=$(ui_kit_get_focus)
    idx=0
    for i in "${!focusables[@]}"; do
        [[ "${focusables[$i]}" == "$current" ]] && idx=$i
    done

    # Cycle
    idx=$(( (idx + dir + ${#focusables[@]}) % ${#focusables[@]} ))
    ui_kit_set_focus "${focusables[$idx]}"
}

# Internal: find all focusable widgets (depth-first order)
_ui_widget_root_find_focusables() {
    local path="$1"
    local wtype

    # Check if this widget is focusable
    wtype=$(ui_kit_get "$path" "type")
    [[ "$wtype" == *focusable* ]] && echo "$path"

    # Recurse into children
    while IFS= read -r child; do
        [[ -z "$child" ]] && continue
        _ui_widget_root_find_focusables "$child"
    done < <(ui_kit_children "$path")
}
