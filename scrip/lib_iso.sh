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

iso_run_inside() {
  local iso_path="$1"
  shift

  local tmp_mount
  tmp_mount=$(mktemp -d)
  (
    set -e

    local cleanup
    cleanup() {
        popd
        fusermount -u "$tmp_mount" || true
        rmdir "$tmp_mount" || true
    }

    trap cleanup EXIT

    fuseiso "$iso_path" "$tmp_mount"

    pushd "$tmp_mount"
    "$@"
  )
}
