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
FILE_PARALLEL_JOBS=3   # Number of PDFs to process simultaneously
PAGE_PARALLEL_JOBS=2    # Number of pages to process per PDF
MAX_WIDTH=1280          # Maximum width for images (pixels)
QUALITY=50              # WebP compression quality (0-100)
MIN_AGE_SECONDS=10      # Minimum age of files to process (to avoid partial uploads)

# Help message
show_help() {
    echo "Usage: $0 [OPTIONS] directory_with_pdfs"
    echo ""
    echo "Options:"
    echo "  -w, --width WIDTH     Maximum width for images (default: $MAX_WIDTH)"
    echo "  -q, --quality QUALITY WebP compression quality 0-100 (default: $QUALITY)"
    echo "  -f, --file-jobs JOBS  Number of parallel PDF files (default: $FILE_PARALLEL_JOBS)"
    echo "  -p, --page-jobs JOBS  Number of parallel pages per PDF (default: $PAGE_PARALLEL_JOBS)"
    echo "  -a, --min-age SECONDS Minimum age of files to process (default: $MIN_AGE_SECONDS)"
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
            -f|--file-jobs)
                FILE_PARALLEL_JOBS="$2"
                shift 2
                ;;
            -p|--page-jobs)
                PAGE_PARALLEL_JOBS="$2"
                shift 2
                ;;
            -a|--min-age)
                MIN_AGE_SECONDS="$2"
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
                INPUT_DIR="$1"
                shift
                ;;
        esac
    done
}

# Function to calculate directory size for specific file types with minimum age
get_dir_size_by_type() {
    local dir="$1"
    local file_pattern="$2"  # e.g. "*.pdf" or "*.tar"
    local min_age="$3"       # in seconds
    local size=0
    
    # For files with minimum age
    if [ "$min_age" -gt 0 ]; then
        # Find files older than min_age and sum their sizes
        size=$(find "$dir" -type f -name "$file_pattern" -mmin +$(echo "scale=2; $min_age/60" | bc) -print0 2>/dev/null | xargs -0 du -bc 2>/dev/null | tail -n1 | cut -f1)
    else
        # Find all files and sum their sizes
        size=$(find "$dir" -type f -name "$file_pattern" -print0 2>/dev/null | xargs -0 du -bc 2>/dev/null | tail -n1 | cut -f1)
    fi
    
    # If du failed or returned nothing, default to 0
    if [[ ! "$size" =~ ^[0-9]+$ ]]; then
        size=0
    fi
    
    echo $size
}

# Process a single PDF file (to be used with parallel)
process_pdf() {
    local pdf_file="$1"
    local max_width="$2"
    local quality="$3"
    local page_jobs="$4"
    local min_age="$5"
    
    # Skip if not a file or not a PDF
    if [ ! -f "$pdf_file" ] || [[ $(file -b --mime-type "$pdf_file") != "application/pdf" ]]; then
        return 1
    fi
    
    # Call the PDF processing script with proper arguments
    ./shrink_pdf.sh -w "$max_width" -q "$quality" -j "$page_jobs" "$pdf_file"
    local result=$?
    
    # Return the result code from shrink_pdf.sh
    return $result
}

# Main function
main() {
    # Parse command-line arguments
    parse_args "$@"
    
    # Ensure a directory is provided as argument
    if [ -z "$INPUT_DIR" ]; then
        echo -e "${RED}Error: No input directory provided${RESET}" >&2
        show_help
    fi

    # Check if input directory exists
    if [ ! -d "$INPUT_DIR" ]; then
        echo -e "${RED}Error: $INPUT_DIR is not a valid directory${RESET}" >&2
        exit 1
    fi

    # Check if shrink_pdf.sh exists and is executable
    if [ ! -x "./shrink_pdf.sh" ]; then
        echo -e "${RED}Error: shrink_pdf.sh is not found or not executable${RESET}" >&2
        exit 1
    fi

    # Set up variables
    LOG_FILE="pdf_shrink_$(date +%Y%m%d_%H%M%S).log"
    ERROR_LOG="pdf_errors_$(date +%Y%m%d_%H%M%S).log"
    
    # Save the start time
    START_TIME=$(date +%s)
    
    # Get initial sizes
    INITIAL_OLD_PDFS=$(get_dir_size_by_type "$INPUT_DIR" "*.pdf" "$MIN_AGE_SECONDS")
    INITIAL_TARS=$(get_dir_size_by_type "$INPUT_DIR" "*.tar" "0")
    ORIGINAL_SIZE=$((INITIAL_OLD_PDFS + INITIAL_TARS))
    
    # Save the list of PDFs to process
    PDFS_TO_PROCESS_FILE=$(mktemp)
    find "$INPUT_DIR" -type f -name "*.pdf" -mmin +$(echo "scale=2; $MIN_AGE_SECONDS/60" | bc) > "$PDFS_TO_PROCESS_FILE"
    TOTAL_FILES=$(wc -l < "$PDFS_TO_PROCESS_FILE")
    
    if [ $TOTAL_FILES -eq 0 ]; then
        echo -e "${RED}Error: No eligible PDF files found in $INPUT_DIR${RESET}" >&2
        rm -f "$PDFS_TO_PROCESS_FILE"
        exit 1
    fi

    # Function to strip ANSI color codes for log file
    strip_colors() {
        sed 's/\x1b\[[0-9;]*m//g'
    }

    # Start logging and console output
    {
        echo -e "${BOLD}===== PDF Compression Summary =====${RESET}"
        echo -e "Started: $(date)"
        echo -e "Directory: ${CYAN}$INPUT_DIR${RESET}"
        echo -e "Files to process: ${YELLOW}$TOTAL_FILES${RESET}"
        echo -e "Original size: ${MAGENTA}$(numfmt --to=iec-i --suffix=B -- $ORIGINAL_SIZE)${RESET}"
        echo -e "Settings: WIDTH=${CYAN}$MAX_WIDTH${RESET}, QUALITY=${CYAN}$QUALITY${RESET}"
        echo -e "Parallelism: FILES=${CYAN}$FILE_PARALLEL_JOBS${RESET}, PAGES=${CYAN}$PAGE_PARALLEL_JOBS${RESET}"
        echo -e "Log file: $LOG_FILE"
        echo -e "Error log file: $ERROR_LOG"
        echo -e "${BOLD}==================================${RESET}"
        echo ""

        # Export the process_pdf function for parallel
        export -f process_pdf
        
        # Process PDF files in parallel
        echo -e "Processing ${YELLOW}$TOTAL_FILES${RESET} PDF files in parallel (using ${YELLOW}$FILE_PARALLEL_JOBS${RESET} jobs)..."
        echo -e "Each PDF will use up to ${YELLOW}$PAGE_PARALLEL_JOBS${RESET} parallel jobs for its pages"
        echo ""
        
        # Process all PDFs from our saved list
        cat "$PDFS_TO_PROCESS_FILE" | \
        parallel --bar --eta -j "$FILE_PARALLEL_JOBS" --joblog "$ERROR_LOG" \
            "process_pdf {} $MAX_WIDTH $QUALITY $PAGE_PARALLEL_JOBS $MIN_AGE_SECONDS" 2>&2
        
        PARALLEL_EXIT_CODE=$?
        if [ $PARALLEL_EXIT_CODE -ne 0 ]; then
            echo -e "${RED}Some files failed to process. Check the error log for details: $ERROR_LOG${RESET}"
        fi

        # Calculate final sizes - only consider PDFs from the start of the run
        FINAL_OLD_PDFS=$(get_dir_size_by_type "$INPUT_DIR" "*.pdf" "$((MIN_AGE_SECONDS + $(date +%s) - START_TIME))")
        FINAL_TARS=$(get_dir_size_by_type "$INPUT_DIR" "*.tar" "0")
        
        # Calculate size changes
        PDF_DECREASE=$((INITIAL_OLD_PDFS - FINAL_OLD_PDFS))
        TAR_INCREASE=$((FINAL_TARS - INITIAL_TARS))
        
        # Calculate savings
        TOTAL_SAVED=$((PDF_DECREASE - TAR_INCREASE))
        
        # Calculate savings percentage
        if [ $INITIAL_OLD_PDFS -gt 0 ]; then
            SAVED_PERCENT=$((TOTAL_SAVED * 100 / INITIAL_OLD_PDFS))
        else
            SAVED_PERCENT=0
        fi
        
        # Calculate time stats
        TOTAL_TIME=$(($(date +%s) - START_TIME))
        TOTAL_HOURS=$((TOTAL_TIME / 3600))
        TOTAL_MINS=$(((TOTAL_TIME % 3600) / 60))
        TOTAL_SECS=$((TOTAL_TIME % 60))
        
        if [ $TOTAL_TIME -gt 0 ]; then
            OVERALL_SPEED=$(echo "scale=2; ${TOTAL_SAVED} / 1048576 / ${TOTAL_TIME}" | bc)
            if [ "$OVERALL_SPEED" = "" ] || [ "$OVERALL_SPEED" = "0" ]; then
                OVERALL_SPEED="0.00"
            fi
        else
            OVERALL_SPEED="N/A"
        fi

        echo -e "${BOLD}===== Final Results =====${RESET}"
        echo -e "Completed: $(date)"
        echo -e "Total processing time: ${YELLOW}${TOTAL_HOURS}h ${TOTAL_MINS}m ${TOTAL_SECS}s${RESET}"
        echo -e "Original size: ${MAGENTA}$(numfmt --to=iec-i --suffix=B -- $ORIGINAL_SIZE)${RESET}"
        echo -e "Total saved: ${GREEN}$(numfmt --to=iec-i --suffix=B -- $TOTAL_SAVED)${RESET} (${GREEN}$SAVED_PERCENT%${RESET})"
        echo -e "Overall average speed: ${BLUE}${OVERALL_SPEED} MB/s${RESET}"
        echo -e "${BOLD}=======================${RESET}"
    } 2> >(tee -a "$LOG_FILE.stderr" >&2) | tee >(strip_colors > "$LOG_FILE")

    # Clean up
    rm -f "$PDFS_TO_PROCESS_FILE"
    
    exit 0
}

# Call the main function
main "$@"
