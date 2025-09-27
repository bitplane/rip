#!/usr/bin/env bash

# Creates temp dir - "disk" for /var/tmp, "ram" (default) for /tmp
# AppArmor blocks FUSE mounts to /var/tmp
make_tmpdir() {
    local storage_type="${1:-ram}"
    case "$storage_type" in
        disk) mktemp -d -p "${TMPDIR:-/var/tmp}" ;;
        ram)  mktemp -d -p "/tmp" ;;
        *)    return 1 ;;
    esac
}

# Gets the date when this filesystem path was last changed
# Usage: fs_last_update ["path"]
fs_last_update() {
    local path="${1:-.}"
    latest=$(
        find "$path" -maxdepth 1 ! -name "." -printf '%T@ %p\n' 2>/dev/null | \
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
    icon_path=$(echo "$icon_path" | tr '\\' '/')
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

        if ! wrestool -x --type=14 "$icon_index" "$icon_path" > "$tmpdir/temp.ico" 2>/dev/null; then
          log_error "wrestool failed to extract icon from $icon_path"
          rm -rf "$tmpdir" || log_warn "Failed to clean up temp directory: $tmpdir"
          return 1
        fi
        
        if ! icotool -x -o "$tmpdir" "$tmpdir/temp.ico" 2>/dev/null; then
          log_error "icotool failed to convert icon from $icon_path"
          rm -rf "$tmpdir" || log_warn "Failed to clean up temp directory: $tmpdir"
          return 1
        fi

        # pick the biggest frame (usually last) and move it up
        if ls "$tmpdir"/*.png >/dev/null 2>&1; then
          largest=$(ls -v "$tmpdir"/*.png | tail -n1)
          mv "$largest" "$dest/icon.png"
        else
          log_error "No PNG files extracted from $icon_path"
          rm -rf "$tmpdir" || log_warn "Failed to clean up temp directory: $tmpdir"
          return 1
        fi

        rm -r "$tmpdir" || log_warn "Failed to clean up temp directory: $tmpdir"
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
  local cleanup_type="fuse"
  
  # Detect format and choose appropriate temp storage
  if command -v udfinfo &>/dev/null && udfinfo "$path" &>/dev/null 2>&1; then
    # UDF needs disk storage for large DVDs
    tmp_mount=$(make_tmpdir "disk")
  else
    # FUSE mounts need /tmp (AppArmor restriction)
    tmp_mount=$(make_tmpdir "ram")
  fi
  
  (
    set -e
    shell_trap "_fs_run_in_cleanup $tmp_mount \$cleanup_type"

    case "$path" in
      *.iso | *.img | /dev/* )
        # Try fuseiso first (for ISO 9660)
        if fuseiso "$path" "$tmp_mount" 2>/dev/null; then
          cleanup_type="fuse"
        elif command -v udfinfo &>/dev/null && udfinfo "$path" &>/dev/null 2>&1; then
          # UDF detected, use 7z extraction
          log_info "🔀 Detected UDF format, using 7z extraction"
          7z x -y -o"$tmp_mount" "$path" >/dev/null 2>&1
          cleanup_type="dir"
        else
          # Fall back to original fuseiso with error
          fuseiso "$path" "$tmp_mount"
          cleanup_type="fuse"
        fi
        ;;
      *)
        archivemount "$path" "$tmp_mount"
        cleanup_type="fuse"
        ;;
    esac

    pushd "$tmp_mount" > /dev/null
    "$@"
  )
}

_fs_run_in_cleanup() {
    local mount_dir="$1"
    local cleanup_type="${2:-fuse}"
    
    # Only popd if we're in the mounted directory
    if [[ "$(pwd)" == "$mount_dir" ]]; then
        popd > /dev/null || log_warn "Failed to popd from mount directory"
    fi
    
    if [[ "$cleanup_type" == "fuse" ]]; then
        fusermount -u "$mount_dir" || true
        rmdir "$mount_dir" || true
    else
        # For 7z extraction, just remove the directory
        rm -rf "$mount_dir" || true
    fi
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

