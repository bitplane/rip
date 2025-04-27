#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scrip/libs.sh"

while true; do
  work=$(queue_wait "$BASE_DIR/3.zip")
  name=$(basename "$work")
  log_info "📦 Compressing $name"

  if ! compress_iso "$work"; then
    log_error "❌ compress_iso failed for $name"
    queue_fail "$work"
    continue
  fi

  queue_success "$work"
done
