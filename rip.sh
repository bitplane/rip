#!/usr/bin/env bash

source ./scrip/libs.sh

deps() {
  local missing=()

  for cmd in tmux fuseiso ddrescue tree ia eject isoinfo xz tar; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Missing required tools: ${missing[*]}" >&2
    echo "Please install the missing dependencies:" >&2
    echo "  sudo apt install tmux fuseiso gddrescue tree" >&2
    echo "  pip install internetarchive" >&2
    return 1
  fi

  if ! ia --help &>/dev/null; then
    echo "❌ Internet Archive CLI not configured. Run 'ia configure' first." >&2
    return 1
  fi

  return 0
}


# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if ! deps; then
    exit 1
  fi
  monitor_tmux "archive"
fi
