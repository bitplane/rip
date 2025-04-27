iso_get_name() {
  local file="$1"

  name=$(isoinfo -d -i "$file" 2>/dev/null | grep "^Volume id:" | sed 's/Volume id:[ ]*//;s/[^A-Za-z0-9._-]/_/g')
  if [[ -n "$name" ]]; then
    # Ensure name is safe for filesystem and URLs
    echo "${name:0:100}"  # Truncate very long names
  else
    echo "UNKNOWN_$(date +%s)"
  fi
}

mount_and_run() {
  local iso_path="$1"
  shift

  local tmp_mount
  tmp_mount=$(mktemp -d)

  (
    set -e
    trap 'fusermount -u "$tmp_mount" || true; rmdir "$tmp_mount" || true' EXIT

    fuseiso "$iso_path" "$tmp_mount"

    export MOUNT_POINT="$tmp_mount"
    "$@"
  )
}
