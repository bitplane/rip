#!/usr/bin/env bash

# contains functions for ripping images

# Usage: rip_tar device outfile
rip_tar() {
    local device="$1"
    local outfile="$2"
    fs_run_in "$1" tar -vcf "$outfile" . || return 1
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
    local sector_size=$(drive_sector_size "$device")
    local out_name="${log_name}.out"
    timeout 1h ddrescue -n -a "$sector_size" -b "$sector_size" "$device" "$iso_name" "$log_name" 2>&1 | tee "$out_name"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
      log_error "⏰ ddrescue either timed out or exited with an error"
    fi

    # Extract the rescue percentage from ddrescue's progress output
    local recovered
    recovered=$(grep -oP 'pct rescued:\s*\K[0-9]+' "$out_name" | tail -n1)
    recovered=${recovered:-0}
    rm -f "$out_name"

    echo "$recovered" | meta_set ddrescue.integrity 0

    if cat "$log_name" | meta_add ddrescue.log; then
        rm -f "${log_name}"* || log_error "Couldn't delete ${log_name}"
    else
        log_error "Failed to store ddrescue log, keeping file: $log_name"
    fi

    if [ "$recovered" -gt 95 ]; then
      log_info  "✅ Recovered ${recovered}% (over 95%)"
    else
      log_error "❌ Recovered ${recovered}% (needs to be over 95%)"
      return 1
    fi
  ) || return 1

}

drive_list() {
  for drive in $(lsblk -d -o NAME,TYPE,MODEL | grep rom | cut -d " " -f 1); do
    echo /dev/"$drive"
  done
}
