#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Configurable settings
MAX_WIDTH=1280    # Maximum width for images (pixels)
QUALITY=50        # WebP compression quality (0-100)
PARALLEL_JOBS=$(nproc)  # Use all available CPUs by default

# Check dependencies
check_dependencies() {
    for cmd in pdfseparate parallel cwebp tar file numfmt du pdftocairo pdfimages; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}Error: $cmd is not installed. Please install it first.${RESET}"
            exit 1
        fi
    done
}

# Help message
show_help() {
    echo "Usage: $0 [OPTIONS] input.pdf"
    echo ""
    echo "Options:"
    echo "  -w, --width WIDTH     Maximum width for images (default: $MAX_WIDTH)"
    echo "  -q, --quality QUALITY WebP compression quality 0-100 (default: $QUALITY)"
    echo "  -j, --jobs JOBS       Number of parallel jobs (default: all CPUs)"
    echo "  -h, --help            Show this help message"
    exit 0
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -w|--width)
                MAX_WIDTH="$2"
                shift 2
                ;;
            -q|--quality)
                QUALITY="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${RESET}"
                show_help
                ;;
            *)
                INPUT_PDF="$1"
                shift
                ;;
        esac
    done
}

# Function to process a single PDF page
process_page() {
    local page_file="$1"
    local output_dir="$2"
    local max_width="$3"
    local quality="$4"
    local page_num=$(basename "$page_file" | sed 's/page-\([0-9]*\).pdf/\1/')
    local page_dir="$output_dir/page-$page_num"
    
    mkdir -p "$page_dir"
    
    # Check if page contains mask layers - FAIL FAST IF THIS ERRORS
    if ! pdfimages -list "$page_file" > "$page_dir/image_list.txt" 2>&1; then
        echo "Error examining PDF page: $page_file" >&2
        return 1
    fi
    
    # Determine if page is landscape by checking PDF dimensions
    local is_landscape=false
    local adjusted_max_width=$max_width
    if command -v pdfinfo &> /dev/null; then
        # Get page dimensions
        local page_info=$(pdfinfo "$page_file" 2>/dev/null)
        if [ $? -eq 0 ]; then
            local page_width=$(echo "$page_info" | grep "Page size" | awk '{print $3}')
            local page_height=$(echo "$page_info" | grep "Page size" | awk '{print $5}')
            
            # Check if numbers are valid
            if [[ "$page_width" =~ ^[0-9.]+$ ]] && [[ "$page_height" =~ ^[0-9.]+$ ]]; then
                # Compare width and height
                if (( $(echo "$page_width > $page_height" | bc -l) )); then
                    is_landscape=true
                    adjusted_max_width=$((max_width * 2))
                fi
            fi
        fi
    fi
    
    if grep -q "mask" "$page_dir/image_list.txt"; then
        # Extract using pdftocairo - FAIL FAST IF THIS ERRORS
        if ! pdftocairo -png -r 150 "$page_file" "$page_dir/img" 2>&1; then
            echo "Error extracting images with pdftocairo: $page_file" >&2
            return 1
        fi
    else
        # Extract using pdfimages - FAIL FAST IF THIS ERRORS
        if ! pdfimages -j -png "$page_file" "$page_dir/img" 2>&1; then
            echo "Error extracting images with pdfimages: $page_file" >&2
            return 1
        fi
    fi
    
    # Check if any images were extracted
    if [ ! "$(find "$page_dir" -type f \( -name "*.png" -o -name "*.jpg" \))" ]; then
        echo "No images extracted from page: $page_file" >&2
        return 1
    fi
    
    # Find extracted images and convert to WebP
    find "$page_dir" -type f \( -name "*.png" -o -name "*.jpg" \) | while read img; do
        local conversion_result=0
        
        # For each image, determine if it's landscape oriented
        local img_width=$(identify -format "%w" "$img" 2>/dev/null)
        local img_height=$(identify -format "%h" "$img" 2>/dev/null)
        local img_max_width=$adjusted_max_width
        
        # If identify command failed or this isn't an image file, use the previously determined max width
        if [[ "$img_width" =~ ^[0-9]+$ ]] && [[ "$img_height" =~ ^[0-9]+$ ]]; then
            if [ $img_width -gt $img_height ] && [ "$is_landscape" = "false" ]; then
                # Individual image is landscape even if the page isn't
                img_max_width=$((max_width * 2))
                echo "Landscape image detected in $img, using width: $img_max_width" >&2
            fi
        fi
        
        if [ "$img_max_width" -gt 0 ]; then
            cwebp -q "$quality" -resize "$img_max_width" 0 "$img" -o "${img}.webp" &>/dev/null || conversion_result=1
        else
            cwebp -q "$quality" "$img" -o "${img}.webp" &>/dev/null || conversion_result=1
        fi
        
        # Check if conversion failed
        if [ $conversion_result -ne 0 ]; then
            echo "Error converting image to WebP: $img" >&2
            return 1
        fi
        
        # Delete original only if WebP was created successfully
        if [ -f "${img}.webp" ]; then
            rm "$img"
        else
            echo "WebP file was not created: $img" >&2
            return 1
        fi
    done
    
    # Remove the original page PDF to save space
    rm "$page_file"
    return 0
}

# Main function
main() {
    # Check dependencies
    check_dependencies
    
    # Parse command-line arguments
    parse_args "$@"
    
    # Ensure a PDF file is provided as argument
    if [ -z "$INPUT_PDF" ]; then
        echo -e "${RED}Error: No input PDF file provided${RESET}"
        show_help
    fi

    # Check if input file exists and is a PDF
    if [ ! -f "$INPUT_PDF" ]; then
        echo -e "${RED}Error: $INPUT_PDF is not a file${RESET}"
        exit 1
    fi
    
    # FAIL FAST: Check if file is a PDF
    local mime_type
    mime_type=$(file -b --mime-type "$INPUT_PDF")
    if [[ "$mime_type" != "application/pdf" ]]; then
        echo -e "${RED}Error: $INPUT_PDF is not a PDF file (detected as $mime_type)${RESET}"
        exit 1
    fi
    
    # FAIL FAST: Check if we can read the PDF info
    if ! pdfinfo "$INPUT_PDF" &>/dev/null; then
        echo -e "${RED}Error: Failed to read PDF info for $INPUT_PDF. File may be corrupt.${RESET}"
        exit 1
    fi

    # Set up variables
    PDF_DIR=$(dirname "$INPUT_PDF")
    BASE_NAME=$(basename "$INPUT_PDF")
    TEMP_DIR="$(mktemp -d)"
    ARCHIVE="${PDF_DIR}/${BASE_NAME%.pdf}.tar"
    
    # FAIL FAST: Check if we can get the file size
    ORIGINAL_SIZE=$(du -bs "$INPUT_PDF" 2>/dev/null | cut -f1)
    if [[ ! "$ORIGINAL_SIZE" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Failed to determine size of $INPUT_PDF${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    ORIGINAL_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B $ORIGINAL_SIZE)

    echo -e "Settings: MAX_WIDTH=${CYAN}$MAX_WIDTH${RESET}, QUALITY=${CYAN}$QUALITY${RESET}, PARALLEL_JOBS=${CYAN}$PARALLEL_JOBS${RESET}"
    echo -e "File: ${BOLD}$BASE_NAME${RESET} (${MAGENTA}$ORIGINAL_SIZE_HUMAN${RESET})"
    echo -e " - Extracting to \"$TEMP_DIR\""

    # Split PDF into individual pages
    echo -e " - Splitting PDF into individual pages"
    mkdir -p "$TEMP_DIR/pages"
    
    # FAIL FAST: Check if PDF can be split
    if ! pdfseparate "$INPUT_PDF" "$TEMP_DIR/pages/page-%d.pdf" 2>/dev/null; then
        echo -e "${RED}Error: Failed to split PDF into pages. File may be corrupt.${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    PAGE_COUNT=$(find "$TEMP_DIR/pages" -name "page-*.pdf" | wc -l)
    if [ $PAGE_COUNT -eq 0 ]; then
        echo -e "${RED}Error: No pages extracted from PDF. File may be corrupt.${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    echo -e " - PDF split into ${YELLOW}$PAGE_COUNT${RESET} pages"

    # Export the function for parallel
    export -f process_page

    # Process all pages in parallel
    echo -e " - Processing ${YELLOW}$PAGE_COUNT${RESET} pages in parallel (using ${YELLOW}$PARALLEL_JOBS${RESET} jobs)..."
    
    # Use a temp file to collect any errors
    ERROR_LOG="$TEMP_DIR/errors.log"
    touch "$ERROR_LOG"
    
    # Process pages and check for errors
    find "$TEMP_DIR/pages" -name "page-*.pdf" | \
    parallel -j "$PARALLEL_JOBS" --halt now,fail=1 \
        "process_page {} $TEMP_DIR $MAX_WIDTH $QUALITY || echo 'Failed to process: {}' >> $ERROR_LOG"
    
    # Check if any errors occurred
    if [ -s "$ERROR_LOG" ]; then
        echo -e "${RED}Error: Some pages failed to process:${RESET}"
        cat "$ERROR_LOG"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Count successful conversions
    WEBP_COUNT=$(find "$TEMP_DIR" -name "*.webp" | wc -l)
    
    # Check if any WebP files were created
    if [ $WEBP_COUNT -eq 0 ]; then
        echo -e " - ${RED}No images could be converted to WebP. Keeping original PDF.${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    echo -e " - Successfully converted ${YELLOW}$WEBP_COUNT${RESET} images to WebP"

    # Calculate new size - using -bs to get a single summarized value
    NEW_SIZE=$(du -bs "$TEMP_DIR" 2>/dev/null | cut -f1)
    if [[ ! "$NEW_SIZE" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Failed to determine size of processed files${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    NEW_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B $NEW_SIZE)
    
    # Make sure we have valid numbers before calculation
    SAVED_BYTES=$((ORIGINAL_SIZE - NEW_SIZE))
    if [ $ORIGINAL_SIZE -gt 0 ]; then
        SAVED_PERCENT=$((SAVED_BYTES * 100 / ORIGINAL_SIZE))
    else
        echo -e "${RED}Error: Original file size is zero${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    SAVED_BYTES_HUMAN=$(numfmt --to=iec-i --suffix=B $SAVED_BYTES)

    echo -e " - Compression results:"
    echo -e "   - Original size: ${MAGENTA}$ORIGINAL_SIZE_HUMAN${RESET}, new size: ${MAGENTA}$NEW_SIZE_HUMAN${RESET}, saved: ${GREEN}$SAVED_BYTES_HUMAN${RESET} (${GREEN}$SAVED_PERCENT%${RESET})"

    # Check if saved percent is suspiciously high
    if [ $SAVED_PERCENT -gt 97 ]; then
        echo -e " - ${RED}Saved percent is suspiciously high (${SAVED_PERCENT}%). Keeping original PDF.${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Check if savings are worth it
    if [ $SAVED_PERCENT -lt 25 ]; then
        echo -e " - ${RED}Space savings less than 25%. Keeping original PDF.${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Create archive
    echo -e " - Archiving all WebP images"
    if ! tar -cf "$ARCHIVE" -C "$TEMP_DIR" .; then
        echo -e " - ${RED}Failed to create archive. Keeping original PDF.${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Check if archive was created successfully
    if [ ! -f "$ARCHIVE" ] || [ ! -s "$ARCHIVE" ]; then
        echo -e " - ${RED}Failed to create archive or archive is empty. Keeping original PDF.${RESET}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Clean up
    rm -rf "$TEMP_DIR"
    rm "$INPUT_PDF"

    echo -e " - Replaced \"$BASE_NAME\" with ${GREEN}\"${BASE_NAME%.pdf}.tar\"${RESET}"
    echo ""
    exit 0
}

# Call the main function
main "$@"