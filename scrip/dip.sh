#!/usr/bin/env bash
# dip.sh - Minimal metadata editor for archive.org items
# Part of the "rip" tool suite

# Find the base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
source "$BASE_DIR/scrip/libs.sh"
source "$BASE_DIR/scrip/lib_dip.sh"

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  dip_main
fi
