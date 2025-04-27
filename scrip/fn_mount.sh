#!/usr/bin/env bash

mount_and_run() {
  local iso_path="$1"
  shift

  local tmp_mount
  tmp_mount=$(mktemp -d)

  (
    set -e
    trap 'fusermount -u "$tmp_mount"; rmdir "$tmp_mount"' EXIT

    fuseiso "$iso_path" "$tmp_mount"

    export MOUNT_POINT="$tmp_mount"
    "$@"
  )
}
