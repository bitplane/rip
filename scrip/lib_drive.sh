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
  eject "$device" || echo "⚠️ Failed to eject $device"
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
    # no scrape, trim, retries, no waiting for 2s, do at least 2k/sec
    # 2k block size, tell me all about it
    ddrescue -n -M -a 2048 -b 2048 -vv "$device" "$iso_name" "$log_name"
  )
}

drive_list() {
  for drive in $(lsblk -d -o NAME,TYPE,MODEL | grep rom | cut -d " " -f 1); do
    echo /dev/"$drive"
  done
}
