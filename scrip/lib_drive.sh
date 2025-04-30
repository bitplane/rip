#!/usr/bin/env bash

# Contains functions for handling CD/DVD drives

drive_wait() {
  local device="$1"
  local printed_waiting=false

  while true; do
    if [ -b "$device" ]; then
      if dd if="$device" bs=2048 count=1 of=/dev/null status=none 2>/dev/null; then
        log_info "✅ Disc detected at $device" >&2
        return 0
      fi
    fi

    if ! $printed_waiting; then
      log_info "💽 Waiting for disc in $device..." >&2
      printed_waiting=true
    fi

    sleep 5
  done
}

drive_eject() {
  local device="$1"
  if eject "$device"; then
    log_info  "⏏️ Ejected $device"
  else
    log_error "⚠️ Failed to eject $device"
  fi
}

drive_list() {
  for drive in $(lsblk -d -o NAME,TYPE,MODEL | grep rom | cut -d " " -f 1); do
    echo /dev/"$drive"
  done
}
