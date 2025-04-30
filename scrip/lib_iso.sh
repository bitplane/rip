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
