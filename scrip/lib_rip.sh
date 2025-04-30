#!/usr/bin/env bash

# contains functions for ripping images

# Usage: rip_tar device outfile
rip_tar() {
    local device="$1"
    local outfile="$2"
    fs_run_in "$1" tar -cf "$outfile" . || return 1
}


rip_ddrescue() {
  local device="$1"
  local output_iso="$2"
  local output_log="$3"
  (
    # use the workdir as the directory to keep user's homedir out of logs
    cd "$(dirname "$output_iso")" || return 1
    local iso_name=$(basename "$output_iso")
    local log_name=$(basename "$output_log")
    
    log_info "🔄 reading disk"
    if ! timeout 1h ddrescue -n -a 2048 -b 2048 "$device" "$iso_name" "$log_name"; then
      log_error "⏰ ddrescue either timed out or exited with an error" 
    fi
  
    recovered=$(rip_ddrescue_percent "$log_name")

    meta_add "recovery.integrity" <<< "${recovered}%"

    if [ "$recovered" -gt 95 ]; then
      log_info  "✅ Recovered ${recovered}% (over 95%)"
    else
      log_error "❌ Recovered ${recovered}% (needs to be over 95%)"
      return 1
    fi
  ) || return 1

}

rip_ddrescue_percent() {
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
