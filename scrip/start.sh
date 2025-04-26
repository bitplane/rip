#!/usr/bin/env bash


source "$(dirname "$0")/fn_tmux.sh"

REQUIRED_CMDS=(fuseiso ddrescue tree xz tmux ia)
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

spawn_tmux_session "archive_session"

