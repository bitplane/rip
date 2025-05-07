#!/usr/bin/env bash
# Zero width space to stop chars from taking up too much space
ZWS=$'\u200B'
EMOJIS="💽$ZWS📄$ZWS📦$ZWS🌍$ZWS✅$ZWS"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

show_latest_line() {
    local pre="$1"
    echo
    while IFS= read -r line; do
        printf "\033[A\033[2K%s\n" "${pre}$line"
    done
    echo
}

# Gets the emoji for a work dir
# Usage: ui_emoji ["path"] 
ui_emoji() {
  local dir="${1:-.}"
  local base=$(basename "$dir")

  # Skip dirs get 
  if [[ $base =~ \.skip$ ]]; then
    echo "❌$ZWS"
    return
  fi

  # Check if the directory is a numbered stage or under a stage
  if [[ $base =~ ^[1-5]\. ]]; then
      local pos=$(( ${base:0:1} * 2))
      echo "${EMOJIS:$pos:2}"
  else
    echo "  "
  fi
}

