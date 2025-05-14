#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR"/scrip/libs.sh

monitor_queue "."
#monitor_queue "." | grep zip | grep -v skip | xxd
echo
monitor_log "archive.log"
