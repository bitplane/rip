#!/usr/bin/env bash

LOGFILE="$(dirname "$(dirname "$0")")/archive.log"

log_line() {
  local message="$1"
  local timestamped="$(date '+%Y-%m-%d %H:%M:%S') "[$$]" $message"
  echo "$timestamped" >> "$LOGFILE"
  echo "$timestamped" >&2
}

send_alert() {
  local message="$1"
  log_line "ALERT: $message"
  
  if command -v notify-send &>/dev/null; then
    notify-send "Archive Pipeline Alert" "$message"
  else
    echo "ALERT: $message" >&2
  fi
}
