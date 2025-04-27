#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scrip/libs.sh"

while true; do
  work=$(queue_wait "$BASE_DIR/4.ship")
  name=$(basename "$work")
  log_info "🔝 Uploading $name"

  if ! upload_directory "$work"; then
    log_error "❌ upload failed for $name"
    queue_fail "$work"
    continue
  fi

  queue_success "$work"
done
