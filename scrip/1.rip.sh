#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/scrip/libs.sh"

DEVICE="${1:-$(drive_list | head -n1)}"
DEVICE="${DEVICE:-/dev/sr0}"

while true; do
    drive_eject  "$DEVICE"
    drive_wait   "$DEVICE" || continue

    name=$(drive_get_name "$DEVICE")
    work="$BASE_DIR/1.rip/$name"
    ext=$(drive_extension "$DEVICE")

    mkdir -p "$work"
    meta_add "scanner" "$work" <<< "rip (https://github.com/bitplane/rip)"

    # todo: use blkcache to avoid reading twice if we run out of memory

    # Try to get a TAR archive first.
    # 1. This puts the data that matters into the blkcache.
    # 2. We can swap the blkcache for a failing cache and re-run, so if I get sick of
    #    waiting for ddrescue and eject the disk, it'll compute integrity including
    #    parts of the disk that tar read.
    #log_info "📦─┐ creating tar for $name"
    #if ! rip_tar "$DEVICE" "$work/$name.tar" \
    #           2>"$work/$name.tar.log"      | \
    #              show_latest_line "        └─ "; then
    #    log_error "❌ TAR failed for $name"
    #    queue_fail "$work"
    #    continue
    #fi

    # If the tar succeeded, we might be able to get a ddrescue image
    log_info "⬇️ ripping $name"
    if ! rip_ddrescue "$DEVICE" \
                      "$work/$name.$ext" \
                      "$work/$name.ddrescue.log"; then

        log_error  "❌ ddrescue failed for $name"
 
        #rm  "$work/$name".iso \
        #    "$work/$name".ddrescue.log*
        queue_fail "$work"
        continue

    #else
    #    # no need for the tar file!
    #    rm "$work/$name.tar"
    fi

    queue_success "$work"
done
