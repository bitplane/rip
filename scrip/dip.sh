#!/usr/bin/env bash
# dip.sh - Minimal metadata editor for archive.org items
# Part of the "rip" tool suite

# Find the base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
source "$BASE_DIR/scrip/libs.sh"

dip_new() {
    ui_widget_add screen dip 0 0 $(tput cols) $(tput lines) /tmp/ui-test
    ui_widget_draw /tmp/ui-test/dip | tr -d '\t'
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dip_new
fi
