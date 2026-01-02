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
