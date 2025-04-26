#!/usr/bin/env bash

mount_iso() {
  local iso_path="$1"
  MOUNT_POINT=$(mktemp -d)

  fuseiso "$iso_path" "$MOUNT_POINT"
}

unmount_iso_and_cleanup() {
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    fusermount -u "$MOUNT_POINT"
    rmdir "$MOUNT_POINT"
    unset MOUNT_POINT
  fi
}
