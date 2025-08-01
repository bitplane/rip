#!/usr/bin/env bash

# The dir above the script dir at the moment
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$BASE_DIR/scrip/lib_shell.sh"
source "$BASE_DIR/scrip/lib_log.sh"
source "$BASE_DIR/scrip/lib_queue.sh"
source "$BASE_DIR/scrip/lib_fs.sh"
source "$BASE_DIR/scrip/lib_meta.sh"
source "$BASE_DIR/scrip/lib_meta_hooks.sh"
source "$BASE_DIR/scrip/lib_monitor.sh"
source "$BASE_DIR/scrip/lib_iso.sh"
source "$BASE_DIR/scrip/lib_floppy.sh"
source "$BASE_DIR/scrip/lib_drive.sh"
source "$BASE_DIR/scrip/lib_rip.sh"
source "$BASE_DIR/scrip/lib_compress.sh"
source "$BASE_DIR/scrip/lib_upload.sh"
source "$BASE_DIR/scrip/lib_ui.sh"
source "$BASE_DIR/scrip/lib_ui_kit.sh"
source "$BASE_DIR/scrip/lib_ui_kit_blit.sh"
