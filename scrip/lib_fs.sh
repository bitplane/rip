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
    IFS=$'\t' read -r icon_path icon_index < <(
        awk -F'[=,]' '
            tolower($1) == "icon" {
                gsub(/^[ \t]+|[ \t]+$/, "", $2)
                gsub(/^[ \t]+|[ \t]+$/, "", $3)
                print $2 "\t" $3
                exit
            }
        ' "$autorun"
    )
    if [ ! -z "$icon_index" ]; then
        icon_index="--name=${icon_index}"
    fi
    icon_path=$(echo $icon_path | tr '\\' '/')
    icon_path=${icon_path//$'\r'/}
    icon_path=$(fs_insensitive "$icon_path" "$src") || return 1

    [[ -z "$icon_path" ]] && return 1

    case "${icon_path,,}" in
      *.ico)
        magick "${icon_path}[0]" -layers merge \
               "$dest/icon.png"
        ;;
      *.exe|*.dll)
        tmpdir=$(mktemp -d)

        wrestool -x --type=14 $icon_index "$icon_path" \
          | icotool -x -o "$tmpdir" -

        # pick the biggest frame (usually last) and move it up
        largest=$(ls -v "$tmpdir"/*.png | tail -n1)
        mv "$largest" "$dest/icon.png"

        rm -r "$tmpdir"
        ;;
      *)
        return 1
    esac
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

    shell_trap "_fs_run_in_cleanup $tmp_mount"

    case "$path" in
      *.iso | /dev/* ) fuseiso      "$path" "$tmp_mount" ;;
      *)               archivemount "$path" "$tmp_mount" ;;
    esac

    pushd "$tmp_mount" > /dev/null
    "$@"
  )
}

_fs_run_in_cleanup() {
    popd > /dev/null
    fusermount -u  "$1" || true
    rmdir          "$1" || true
}

# Gets the real path given a case insensitive one
# Usage: path=$(fs_insensitive PaTH [base])
fs_insensitive() {
    local path="$1"
    local base="${2:-.}"
    IFS='/' read -ra parts <<< "$path"
    for part in "${parts[@]}"; do
        match=$(find "$base" -mindepth 1 -maxdepth 1 -iname "$part" -print -quit)
        if [[ -z "$match" ]]; then
            return 1  # fail
        fi
        base="$match"
    done
    echo "$base"
}

