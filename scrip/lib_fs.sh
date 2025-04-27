
fs_last_update() {
  local mount_point="$1"
  latest=$(
    find "$mount_point" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -nr | \
        head -n1 | \
        cut -d' ' -f1 | \
        cut -d'.' -f1)
  date -d "@$latest" +"%Y-%m-%d"
}

fs_tree() {
  local mount_point="$1"
  local output_file="$2"

  pushd "$mount_point" >/dev/null
  tree -D --timefmt=%Y-%m-%d --du -h -n .
  popd >/dev/null
}
