iso_is_udf() {
  local file="$1"
  udfinfo "$file" >/dev/null 2>&1
}

iso_get_name() {
  local file="$1"

  # Try ISO 9660 first
  name=$(isoinfo -d -i "$file" 2>/dev/null | grep "^Volume id:" | sed 's/Volume id:[ ]*//;s/[^A-Za-z0-9._-]/_/g;s/__*/_/g;s/_*$//')
  
  # If ISO fails, try UDF
  if [[ -z "$name" ]] && iso_is_udf "$file"; then
    name=$(udflabel "$file" 2>/dev/null | sed 's/[^A-Za-z0-9._-]/_/g;s/__*/_/g;s/_*$//')
  fi
  
  if [[ -n "$name" ]]; then
    # Ensure name is safe for filesystem and URLs
    echo "${name:0:100}"  # Truncate very long names
  else
    echo "UNKNOWN_$(date +%s)"
  fi
}

iso_get_info() {
    local file="$1"
    isoinfo -d -i "$file" 2>/dev/null | grep -vE ': $'
}

iso_get_udf_info() {
    local file="$1"
    udfinfo "$file" 2>/dev/null
}
