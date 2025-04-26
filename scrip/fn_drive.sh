#!/usr/bin/env bash

wait_for_disc() {
  local device="$1"
  local printed_waiting=false

  while true; do
    if [ -b "$device" ]; then
      if dd if="$device" bs=2048 count=1 of=/dev/null status=none 2>/dev/null; then
        echo "✅ Disc detected at $device" >&2
        return 0
      fi
    fi

    if ! $printed_waiting; then
      echo "⌛ Waiting for disc in $device..." >&2
      printed_waiting=true
    fi

    sleep 5
  done
}

get_disc_name() {
  local device_or_iso="$1"

  name=$(isoinfo -d -i "$device_or_iso" 2>/dev/null | grep "^Volume id:" | sed 's/Volume id:[ ]*//;s/ /_/g')
  if [[ -n "$name" ]]; then
    echo "$name"
  else
    echo "UNKNOWN_$(date +%s)"
  fi
}

eject_disc() {
  local device="$1"
  eject "$device" || echo "⚠️ Failed to eject $device"
}

create_image() {
  local device="$1"
  local output_iso="$2"
  local output_log="$3"

  ddrescue -b 2048 -n "$device" "$output_iso" "$output_log"
  ddrescue -b 2048 -r3 "$device" "$output_iso" "$output_log"
}
