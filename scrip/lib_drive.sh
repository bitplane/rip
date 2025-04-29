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

drive_dump() {
  local device="$1"
  local output_iso="$2"
  local output_log="$3"
  
  (
    # use the same directory as the output iso
    # to keep the user's homedir out of logs
    cd "$(dirname "$output_iso")" || return 1
    local iso_name=$(basename "$output_iso")
    local log_name=$(basename "$output_log")
    
    log_info "🔄 reading disk"
    if ! timeout 1h ddrescue -n -a 2048 -b 2048 "$device" "$iso_name" "$log_name"; then
      log_error "⏰ ddrescue either timed out or exited with an error" 
    fi
  
    recovered=$(drive_ddrescue_percent "$log_name")

    meta_add . "recovery.itegrity" <<< "${recovered}%"

    if [ "$recovered" -gt 95 ]; then
      log_info  "✅ Recovered ${recovered}% (over 95%)"
    else
      log_error "❌ Recovered ${recovered}% (needs to be over 95%)"
      return 1
    fi
  ) || return 1

}

drive_ddrescue_percent() {
  local log_file="$1"

  awk '
  /^0x/ {
      size = strtonum($2)
      total += size
      if ($3 == "+") good += size
  }
  END {
      if (total == 0) {
          print 0
          exit
      }
      percent = int((good * 100) / total)
      print percent
  }
  ' "$log_file" 2>/dev/null || echo 0
}

drive_list() {
  for drive in $(lsblk -d -o NAME,TYPE,MODEL | grep rom | cut -d " " -f 1); do
    echo /dev/"$drive"
  done
}
