#!/bin/bash

#
# Hooks for metadata changes
#

# When the ddrescue log is added, derive integrity from the captured
# ddrescue.output (its live stats). The mapfile alone can't tell a short-read
# bail from a clean rip — both end up as a single '+' region.
meta_hook_ddrescue.log() {
    meta_get ddrescue.output "" "$3" \
        | grep 'pct rescued:' \
        | tail -n1 \
        | grep -oE '[0-9]+' \
        | head -n1 \
        | meta_set ddrescue.integrity "$2" "$3"
}

