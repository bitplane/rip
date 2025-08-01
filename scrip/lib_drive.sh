#!/usr/bin/env bash

# Contains functions for handling CD/DVD drives

drive_wait() {
  local device="$1"
  local printed_waiting=false
  local icon=$(drive_icon "$device")

  while true; do
    if [ -b "$device" ]; then
      # Try reading with appropriate block size
      local bs=$(drive_sector_size "$device")
      if timeout 1 dd if="$device" bs="$bs" count=1 of=/dev/null status=none 2>/dev/null; then
        log_info "✅ $icon detected at $device" >&2
        return 0
      fi
    fi

    if ! $printed_waiting; then
      log_info "$icon Waiting for disc in $device..." >&2
      printed_waiting=true
    fi

    sleep 5
  done
}

drive_eject() {
  local device="$1"
  local icon=$(drive_icon "$device")
  
  # Try auto-eject first
  if eject "$device" 2>/dev/null; then
    log_info  "⏏️ Ejected $device"
    return
  fi
  
  # For devices that don't support auto-eject, wait for manual removal
  local printed_waiting=false
  while timeout 1 dd if="$device" bs=512 count=1 of=/dev/null status=none 2>/dev/null; do
    if ! $printed_waiting; then
      log_info "$icon Waiting for disk removal from $device..."
      printed_waiting=true
    fi
    sleep 2
  done
}

drive_list() {
  # List CD/DVD drives
  for drive in $(lsblk -d -o NAME,TYPE,MODEL | grep rom | cut -d " " -f 1); do
    echo /dev/"$drive"
  done
  
  # List traditional floppy drives
  for dev in /dev/fd0 /dev/fd1; do
    [ -b "$dev" ] && echo "$dev"
  done
  
  # List USB floppies (removable devices ~1.44MB or ~720KB)
  for dev in /dev/sd[a-z]; do
    local dev_name="${dev##*/}"  # Strip /dev/ prefix
    if [ -b "$dev" ] && [ -f "/sys/block/$dev_name/removable" ] && 
       [ "$(cat /sys/block/$dev_name/removable)" = "1" ]; then
      
      # Check device model for floppy indicators first
      local model=""
      [ -f "/sys/block/$dev_name/device/model" ] && model=$(cat "/sys/block/$dev_name/device/model" 2>/dev/null | tr '[:upper:]' '[:lower:]')
      if [[ "$model" == *"floppy"* ]] || [[ "$model" == *"fd"* ]] || [[ "$model" == *"uf000"* ]]; then
        echo "$dev"
        continue
      fi
      
      # Only check size if disk is present and readable
      if timeout 1 dd if="$dev" bs=512 count=1 of=/dev/null status=none 2>/dev/null; then
        local size=$(blockdev --getsize64 "$dev" 2>/dev/null)
        # 1.44MB = 1474560, 720KB = 737280
        if [ "$size" = "1474560" ] || [ "$size" = "737280" ]; then
          echo "$dev"
        fi
      fi
    fi
  done
}

# Identify drive type
drive_type() {
  local device="$1"
  
  # Check if it's a CD/DVD ROM
  if lsblk -d -o NAME,TYPE "$device" 2>/dev/null | grep -q rom; then
    echo "cdrom"
    return
  fi
  
  # Check if it's a traditional floppy
  case "$device" in
    /dev/fd[0-9]*)
      echo "floppy"
      return
      ;;
  esac
  
  # Check if it's a USB floppy
  local dev_name="${device##*/}"  # Strip /dev/ prefix
  if [ -f "/sys/block/$dev_name/removable" ] && 
     [ "$(cat /sys/block/$dev_name/removable)" = "1" ]; then
    
    # Only check size if disk is present and readable
    if timeout 1 dd if="$device" bs=512 count=1 of=/dev/null status=none 2>/dev/null; then
      local size=$(blockdev --getsize64 "$device" 2>/dev/null)
      if [ "$size" = "1474560" ] || [ "$size" = "737280" ]; then
        echo "floppy"
        return
      fi
    fi
    
    # Check device model for floppy indicators
    local model=""
    [ -f "/sys/block/$dev_name/device/model" ] && model=$(cat "/sys/block/$dev_name/device/model" 2>/dev/null | tr '[:upper:]' '[:lower:]')
    if [[ "$model" == *"floppy"* ]] || [[ "$model" == *"fd"* ]] || [[ "$model" == *"uf000"* ]]; then
      echo "floppy"
      return
    fi
    
    # Check if it's exactly 1.44MB or 720KB capacity device (even without disk)
    local size_file="/sys/block/$dev_name/size"
    if [ -f "$size_file" ]; then
      local sectors=$(cat "$size_file" 2>/dev/null)
      # 1.44MB = 2880 sectors, 720KB = 1440 sectors (512 bytes per sector)
      if [ "$sectors" = "2880" ] || [ "$sectors" = "1440" ]; then
        echo "floppy"
        return
      fi
    fi
  fi
  
  echo "unknown"
}

# Get appropriate file extension
drive_extension() {
  local device="$1"
  case "$(drive_type "$device")" in
    cdrom)  echo "iso" ;;
    floppy) echo "img" ;;
    *)      echo "bin" ;;
  esac
}

# Get sector size for device
drive_sector_size() {
  local device="$1"
  case "$(drive_type "$device")" in
    cdrom)  echo "2048" ;;
    floppy) echo "512" ;;
    *)      echo "512" ;;
  esac
}

# Get disk name based on drive type
drive_get_name() {
  local device="$1"
  local name=""
  
  case "$(drive_type "$device")" in
    cdrom)
      # Use existing ISO naming
      name=$(iso_get_name "$device")
      ;;
    floppy)
      # Use the dedicated floppy library function
      name=$(floppy_get_name "$device")
      ;;
    *)
      name="DISK_$(date +%s)"
      ;;
  esac
  
  echo "${name:0:100}"  # Truncate very long names
}

# Get drive icon emoji
drive_icon() {
  local device="$1"
  case "$(drive_type "$device")" in
    cdrom)  echo "💿" ;;
    floppy) echo "💾" ;;
    *)      echo "💽" ;;  # generic disk
  esac
}
