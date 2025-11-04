#!/usr/bin/env bash

# Notification functions for success/failure states
# Uses multiple notification methods for maximum compatibility

# Notify success - does nothing, success is the expected case
# Usage: ui_notify_success "stage" "message"
ui_notify_success() {
  local stage="$1"
  local message="$2"

  # Keyboard notification (non-blocking, ignore errors)
  (command -v keyboard-notify >/dev/null 2>&1 && \
   keyboard-notify --bg-color 0,255,0 && \
   sleep 2 && \
   keyboard-reset) & disown 2>/dev/null || true
}

# Notify failure
# Usage: ui_notify_failure "stage" "message"
ui_notify_failure() {
  local stage="$1"
  local message="$2"

  # Terminal bell
  echo -e '\a'

  # Keyboard notification (non-blocking, ignore errors)
  (command -v keyboard-notify >/dev/null 2>&1 && \
   keyboard-notify --bg-color 255,0,0 && \
   sleep 2 && \
   keyboard-reset) & disown 2>/dev/null || true

  # XDG notification (ignore if not available)
  command -v notify-send >/dev/null 2>&1 && \
    notify-send -u critical "❌ $stage" "$message" 2>/dev/null || true
}
