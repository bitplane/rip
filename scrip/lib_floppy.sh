#!/usr/bin/env bash

# Contains functions for handling floppy disks and FAT filesystems

# Get volume label from FAT12/FAT16 floppy disk
floppy_get_name() {
  local device="$1"
  local label=""
  
  # First, check if we can read the disk
  if ! timeout 1 dd if="$device" bs=512 count=1 of=/dev/null status=none 2>/dev/null; then
    echo "FLOPPY_$(date +%s)"
    return
  fi
  
  # Use blkid to get the filesystem label (much simpler!)
  label=$(blkid -s LABEL -o value "$device" 2>/dev/null)
  
  # Sanitize and validate label
  if [ -n "$label" ] && [ "$label" != "NO NAME" ] && [ "$label" != "NO_NAME" ] && ! [[ "$label" =~ ^[[:space:]]+$ ]]; then
    # Replace non-alphanumeric chars with underscore
    label=$(echo "$label" | sed 's/[^A-Za-z0-9._-]/_/g' | sed 's/_\+/_/g' | sed 's/^_\|_$//')
    if [ -n "$label" ]; then
      echo "${label:0:100}"
      return
    fi
  fi
  
  # If no label, try to get a descriptive name from file command
  local file_info=$(file -s "$device" 2>/dev/null)
  if [[ "$file_info" == *"OEM-ID"* ]]; then
    local oem=$(echo "$file_info" | sed -n 's/.*OEM-ID "\([^"]*\)".*/\1/p' | sed 's/[^A-Za-z0-9._-]/_/g')
    if [ -n "$oem" ] && [ "$oem" != "MSDOS5_0" ] && [ "$oem" != "mkfs_fat" ]; then
      echo "${oem:0:100}"
      return
    fi
  fi
  
  # Default to timestamp-based name
  echo "FLOPPY_$(date +%s)"
}

# Try to find volume label in root directory
floppy_get_root_dir_label() {
  local device="$1"
  
  # Read boot sector parameters (single read for efficiency)
  local boot_sector=$(dd if="$device" bs=512 count=1 2>/dev/null | od -An -tx1 -v)
  
  # Extract parameters from boot sector hex dump
  local bytes_per_sector=$(echo "$boot_sector" | dd bs=1 skip=$((11*3)) count=6 2>/dev/null | xxd -r -p | od -An -td2 --endian=little | tr -d ' ')
  local reserved_sectors=$(echo "$boot_sector" | dd bs=1 skip=$((14*3)) count=6 2>/dev/null | xxd -r -p | od -An -td2 --endian=little | tr -d ' ')
  local num_fats=$(echo "$boot_sector" | dd bs=1 skip=$((16*3)) count=3 2>/dev/null | xxd -r -p | od -An -td1 | tr -d ' ')
  local root_entries=$(echo "$boot_sector" | dd bs=1 skip=$((17*3)) count=6 2>/dev/null | xxd -r -p | od -An -td2 --endian=little | tr -d ' ')
  local sectors_per_fat=$(echo "$boot_sector" | dd bs=1 skip=$((22*3)) count=6 2>/dev/null | xxd -r -p | od -An -td2 --endian=little | tr -d ' ')
  
  # Simpler approach - just read key values directly
  bytes_per_sector=512  # Standard for floppies
  reserved_sectors=$(dd if="$device" bs=1 skip=14 count=2 2>/dev/null | od -An -td2 --endian=little | tr -d ' ')
  num_fats=$(dd if="$device" bs=1 skip=16 count=1 2>/dev/null | od -An -td1 | tr -d ' ')
  root_entries=$(dd if="$device" bs=1 skip=17 count=2 2>/dev/null | od -An -td2 --endian=little | tr -d ' ')
  sectors_per_fat=$(dd if="$device" bs=1 skip=22 count=2 2>/dev/null | od -An -td2 --endian=little | tr -d ' ')
  
  # Validate parameters
  if [ -z "$reserved_sectors" ] || [ -z "$num_fats" ] || 
     [ -z "$sectors_per_fat" ] || [ -z "$root_entries" ]; then
    return
  fi
  
  # Calculate root directory location and size
  local root_dir_start=$((reserved_sectors + (num_fats * sectors_per_fat)))
  local root_dir_sectors=$(((root_entries * 32 + 511) / 512))  # Round up
  
  # Read entire root directory at once
  local root_data=$(dd if="$device" bs=512 skip="$root_dir_start" count="$root_dir_sectors" 2>/dev/null | od -An -tx1 -v)
  
  # Search for volume label entry (attribute 0x08 at offset 11 of each 32-byte entry)
  local i=0
  while [ $i -lt $root_entries ]; do
    local entry_offset=$((i * 32))
    local attr_offset=$((entry_offset + 11))
    
    # Extract attribute byte (2 hex chars + space = 3 chars per byte in od output)
    local attr_pos=$((attr_offset * 3))
    local attr="${root_data:$attr_pos:2}"
    
    if [ "$attr" = "08" ]; then
      # Extract 11-byte filename (volume label)
      local name_pos=$((entry_offset * 3))
      local hex_name="${root_data:$name_pos:33}"  # 11 bytes * 3 chars = 33
      
      # Convert hex to ASCII
      local label=$(echo "$hex_name" | sed 's/ //g' | xxd -r -p | tr -d '\0' | sed 's/[[:space:]]*$//')
      
      if [ -n "$label" ] && ! [[ "$label" =~ ^[[:space:]]+$ ]]; then
        echo "$label"
        return
      fi
    fi
    
    i=$((i + 1))
  done
}

# Get floppy disk information
floppy_get_info() {
  local device="$1"
  
  if ! dd if="$device" bs=512 count=1 of=/dev/null status=none 2>/dev/null; then
    echo "No disk in drive"
    return
  fi
  
  # Read basic parameters
  local oem=$(dd if="$device" bs=1 skip=3 count=8 2>/dev/null | tr -d '\0' | sed 's/[[:space:]]*$//')
  local bytes_per_sector=$(dd if="$device" bs=1 skip=11 count=2 2>/dev/null | od -An -td2 --endian=little | tr -d ' ')
  local total_sectors=$(dd if="$device" bs=1 skip=19 count=2 2>/dev/null | od -An -td2 --endian=little | tr -d ' ')
  local media_type=$(dd if="$device" bs=1 skip=21 count=1 2>/dev/null | od -An -tx1 | tr -d ' ')
  
  echo "OEM Name: $oem"
  echo "Bytes per sector: $bytes_per_sector"
  echo "Total sectors: $total_sectors"
  
  # Determine disk type by media descriptor
  case "$media_type" in
    f0) echo "Media type: 3.5\" HD (1.44MB)" ;;
    f9) echo "Media type: 3.5\" DD (720KB)" ;;
    fd) echo "Media type: 5.25\" (360KB)" ;;
    *) echo "Media type: Unknown (0x$media_type)" ;;
  esac
  
  # Calculate capacity
  if [ -n "$bytes_per_sector" ] && [ -n "$total_sectors" ] && [ "$total_sectors" -gt 0 ]; then
    local capacity=$((bytes_per_sector * total_sectors))
    echo "Capacity: $capacity bytes ($((capacity / 1024))KB)"
  fi
}