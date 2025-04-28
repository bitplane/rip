queue_count() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l
}

queue_wait() {
  local dir="$1"
  local work
  log_info "🔍 watching $(basename "$dir") for work" >&2
  while true; do
    work=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
    if [[ -n "$work" ]]; then
      log_info "📂 found $work" >&2
      echo "$work"
      return 0
    fi
    sleep 5
  done
}

# gets the next stage number from the directory name
# eg: 1.rip -> 2.snip
queue_get_next_stage() {
  local queue_dir
  local stage
  local next_stage
  local next_stage_dir
  queue_dir=$(realpath "$1")
  stage=$(basename "$queue_dir" | cut -d'.' -f1)
  next_stage=$((stage + 1))
  next_stage_dir=$(find "${BASE_DIR}" -maxdepth 1 -type d -name "${next_stage}.*" ! -name "*.skip" | head -n1)
  
  if [[ -z "$next_stage_dir" ]]; then
    log_alert "💣 SCRIPT FAILURE: NO NEXT STAGE FOUND FOR $queue_dir"
    return 1
  fi
  
  # Return the full absolute path
  realpath "$next_stage_dir"
}

queue_success() {
  local work="$1"
  local next_stage
  local dest
  next_stage=$(queue_get_next_stage "$(dirname "$work")") || return 1
  dest="$next_stage/$(basename "$work")"
  
  if [[ -d "$dest" ]]; then
    dest="${dest}"_$(date '+%Y%m%d_%H%M%S')
  fi
  
  log_info "🎉 moving $work to $dest"
  mv "$work" "$dest" || return 1
}

queue_get_fail_dir() {
  local work_dir
  local queue_dir
  local fail_dir
  work_dir=$(realpath "$1")
  queue_dir=$(dirname "$work_dir")
  fail_dir="${queue_dir}.skip"

  realpath "$fail_dir"
}

queue_fail() {
  local work="$1"
  local fail_dir
  local dest
  fail_dir=$(queue_get_fail_dir "$work") || return 1
  dest="$fail_dir/$(basename "$work")"

  if [[ -d "$dest" ]]; then
    dest=${fail_dir}/$(basename "$work")_$(date '+%Y%m%d_%H%M%S')
  fi

  log_error "💩 moving $work to $dest"
  mv "$work" "$dest"
}
