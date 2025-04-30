#!/usr/bin/env bash

# Gets the date when this filesystem path was last changed
# Usage: fs_last_update ["path"]
fs_last_update() {
    local path="${1:-.}"
    latest=$(
        find "$path" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -nr       | head -n1        | \
        cut  -d' ' -f1 | cut -d'.' -f1)  || return 1
    date -d "@$latest" +"%Y-%m-%d" 
}

# Gets a tree of a filesystem
# Usage: fs_tree ["path"]
fs_tree() {
    local path="${1:-.}"
    (
        set -e
        cd "$path"
        tree -D --timefmt=%Y-%m-%d --du -h -n .
    ) || return 1
}


# extract the icon if there is one, convert to png
# Usage: fs_extrac_icon "mount" ["dest"]
fs_extract_icon() {
    local src="$1"
    local dest="${2:-.}"

    # Find autorun.inf (case insensitive)
    local autorun
    autorun=$(find "$src" -maxdepth 1 -iname 'autorun.inf' -print -quit)
    [[ "$autorun" ]] || return 1


    local icon_path
    local icon_index
    read icon_path icon_index <<<"$(awk -F'[=,]' \
        'tolower($1)=="icon"{print $2, $3; exit}' "$autorun")"

    icon_index=${icon_index:-0}
    icon_path=${icon_path//\\//}
    full_icon_path="$src/$icon_path"

    [[ -f "$full_icon_path" ]] || return 1

    case "${full_icon_path,,}" in
      *.ico)
        # keep what you already do
        magick convert "${full_icon_path}[0]" -layers merge \
                       "$dest/icon.png"
        ;;
      *.exe|*.dll)
        mkdir -p "$dest/.work"
        wrestool -x --type=14 --name="$icon_index" "$full_icon_path" \
          | icotool -x -o "$dest/.work" -

        # pick the biggest frame (usually last) and move it up
        largest=$(ls -v "$dest/.work"/*.png | tail -n1)
        mv "$largest" "$dest/icon.png"
        rm -r "$dest/.work"
        ;;
      *)
        return 1
    esac

    magick convert "$full_icon_path" "$dest/icon.png" || return 1
}

# Gets the full path to an existing file or dir
# ensuring dirs end with /
# Usage: fs_path "path"
fs_path() {
    [[ -d $1 ]] && realpath "$1"/ && return
    [[ -f $1 ]] && realpath "$1"  && return
    return 1
}

# Mounts an image in a temporary directory, cds into it and runs the command
# fs_mount_and_run "image_to_mount" command to run --etc
fs_run_in() {
  local path="$1"
  shift

  local tmp_mount
  tmp_mount=$(mktemp -d)
  (
    set -e

    local cleanup
    cleanup() {
        popd
        fusermount -u "$tmp_mount" || true
        rmdir "$tmp_mount" || true
    }

    trap cleanup EXIT

    archivemount "$path" "$tmp_mount"

    pushd "$tmp_mount"
    "$@"
  )
}

