#!/bin/bash

# Generic script to tar leaf directories containing specific file types
# Designed for archive.org preparation - handles nasty paths with spaces, parens, etc.
#
# Usage: ./archive_leaf_dirs.sh [options] <directory>
#
# Examples:
#   # Archive all leaf dirs with PDFs
#   ./archive_leaf_dirs.sh --ext pdf "/path/to/data"
#   
#   # Dry run for monthly dirs in Met Office data
#   ./archive_leaf_dirs.sh --dry-run --pattern "*_*_*" --ext pdf "/path/to/year/2012_BI"
#   
#   # Archive with verification and parallel processing
#   ./archive_leaf_dirs.sh --ext pdf --parallel 8 --verify "/path/to/data"

set -euo pipefail

# Defaults
FILE_EXTENSIONS="pdf"
DRY_RUN=false
DIR_PATTERN="*"
PARALLEL_JOBS=4
VERIFY=true
LOG_FILE=""
MIN_FILES=1
REMOVE_ORIGINAL=true

usage() {
    cat << EOF
Usage: $0 [options] <directory>

Archive leaf directories (no subdirs) containing specific file types into tar files.
Handles paths with spaces, parentheses, and special characters.

Options:
    --ext EXT[,EXT2,...]  File extensions to look for (default: pdf)
    --pattern PATTERN     Directory name pattern to match (default: *)
    --dry-run            Show what would be done without doing it
    --parallel N         Number of parallel tar operations (default: 4)
    --no-verify          Skip tar verification
    --no-remove          Don't remove original directories after archiving
    --min-files N        Minimum files required to archive (default: 1)
    --log FILE           Log to specific file (default: archive_TIMESTAMP.log)
    --help               Show this help

Examples:
    # Archive all PDF directories
    $0 --ext pdf /path/to/data

    # Archive only monthly dirs (YYYY_MM_XX pattern)
    $0 --pattern "*_*_*" --ext pdf /path/to/year_dir

    # Multiple extensions
    $0 --ext pdf,jpg,png /path/to/mixed_data

    # Dry run with custom log
    $0 --dry-run --log test.log /path/to/data
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ext)
            FILE_EXTENSIONS="$2"
            shift 2
            ;;
        --pattern)
            DIR_PATTERN="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --parallel)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --no-verify)
            VERIFY=false
            shift
            ;;
        --no-remove)
            REMOVE_ORIGINAL=false
            shift
            ;;
        --min-files)
            MIN_FILES="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Validate
if [ -z "${TARGET_DIR:-}" ]; then
    echo "Error: No directory specified"
    usage
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Set default log file if not specified
if [ -z "$LOG_FILE" ]; then
    LOG_FILE="archive_$(date +%Y%m%d_%H%M%S).log"
fi

# Convert comma-separated extensions to find pattern
build_find_pattern() {
    local exts="$1"
    local pattern=""
    IFS=',' read -ra EXT_ARRAY <<< "$exts"
    for ext in "${EXT_ARRAY[@]}"; do
        [ -n "$pattern" ] && pattern="$pattern -o "
        pattern="$pattern -iname \"*.${ext}\""
    done
    echo "$pattern"
}

# Logging
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    [ -n "$LOG_FILE" ] && echo "$msg" >> "$LOG_FILE"
}

# Count files matching extensions
count_matching_files() {
    local dir="$1"
    local pattern=$(build_find_pattern "$FILE_EXTENSIONS")
    eval "find \"$dir\" -maxdepth 1 -type f \\( $pattern \\) 2>/dev/null | wc -l"
}

# Archive a single directory
archive_directory() {
    local dir="$1"
    local parent_dir=$(dirname "$dir")
    local dir_name=$(basename "$dir")
    local tar_file="$parent_dir/${dir_name}.tar"
    
    # Skip if tar exists
    if [ -f "$tar_file" ]; then
        log "  SKIP: $tar_file already exists"
        return 1
    fi
    
    # Count matching files
    local file_count=$(count_matching_files "$dir")
    
    if [ "$file_count" -lt "$MIN_FILES" ]; then
        return 1
    fi
    
    local size_mb=$(($(du -sb "$dir" 2>/dev/null | cut -f1) / 1024 / 1024))
    log "  Processing: $dir_name ($file_count files, ${size_mb}MB)"
    
    if [ "$DRY_RUN" = true ]; then
        log "    Would create: $tar_file"
        [ "$REMOVE_ORIGINAL" = true ] && log "    Would remove: $dir"
        return 0
    fi
    
    # Create tar
    if ! (cd "$parent_dir" && tar -cf "${dir_name}.tar" "$dir_name" 2>/dev/null); then
        log "    ERROR: Failed to create tar"
        return 1
    fi
    
    # Verify if requested
    if [ "$VERIFY" = true ]; then
        local tar_count=$(tar -tf "$tar_file" 2>/dev/null | wc -l)
        if [ "$tar_count" -lt "$file_count" ]; then
            log "    ERROR: Verification failed (files: $file_count, in tar: $tar_count)"
            rm -f "$tar_file"
            return 1
        fi
    fi
    
    log "    Created: $tar_file"
    
    # Remove original if requested
    if [ "$REMOVE_ORIGINAL" = true ]; then
        if rm -rf "$dir"; then
            log "    Removed: $dir"
        else
            log "    ERROR: Failed to remove $dir"
            return 1
        fi
    fi
    
    return 0
}

export -f archive_directory count_matching_files build_find_pattern log
export FILE_EXTENSIONS DRY_RUN VERIFY REMOVE_ORIGINAL MIN_FILES LOG_FILE

# Main
log "Starting archive operation"
log "Target: $TARGET_DIR"
log "Extensions: $FILE_EXTENSIONS"
log "Pattern: $DIR_PATTERN"
log "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "LIVE")"
log ""

# Find and process leaf directories
processed=0
errors=0

while IFS= read -r -d '' dir; do
    # Check if it's a leaf directory (no subdirs)
    if find "$dir" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null | grep -q .; then
        continue
    fi
    
    # Check if it has matching files
    if [ $(count_matching_files "$dir") -ge "$MIN_FILES" ]; then
        if archive_directory "$dir"; then
            ((processed++)) || true
        else
            ((errors++)) || true
        fi
    fi
done < <(find "$TARGET_DIR" -type d -name "$DIR_PATTERN" -print0)

# Summary
log ""
log "Operation complete. Check log: $LOG_FILE"
log "Processed: $processed"
log "Errors: $errors"