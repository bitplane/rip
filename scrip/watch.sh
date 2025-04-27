#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR"/scrip/libs.sh

while true; do
  clear
  monitor_queue "."
  monitor_log "archive.log"
  sleep 5
done

