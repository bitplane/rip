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
FILE_PARALLEL_JOBS=12   # Number of PDFs to process simultaneously
PAGE_PARALLEL_JOBS=8    # Number of pages to process per PDF
MAX_WIDTH=1280          # Maximum width for images (pixels)
QUALITY=50              # WebP compression quality (0-100)

# Help message
show_help() {
    echo "Usage: $0 [OPTIONS] directory_with_pdfs"
    echo ""
    echo "Options:"
    echo "  -w, --width WIDTH     Maximum width for images (default: $MAX_WIDTH)"
    echo "  -q, --quality QUALITY WebP compression quality 0-100 (default: $QUALITY)"
    echo "  -f, --file-jobs JOBS  Number of parallel PDF files (default: $FILE_PARALLEL_JOBS)"
    echo "  -p, --page-jobs JOBS  Number of parallel pages per PDF (default: $PAGE_PARALLEL_JOBS)"
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

# Process a single PDF file (to be used with parallel)
process_pdf() {
    local pdf_file="$1"
    local max_width="$2"
    local quality="$3"
    local page_jobs="$4"
    
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
        echo -e "${RED}Error: No input directory provided${RESET}"
        show_help
    fi

    # Check if input directory exists
    if [ ! -d "$INPUT_DIR" ]; then
        echo -e "${RED}Error: $INPUT_DIR is not a valid directory${RESET}"
        exit 1
    fi

    # Check if shrink_pdf.sh exists and is executable
    if [ ! -x "./shrink_pdf.sh" ]; then
        echo -e "${RED}Error: shrink_pdf.sh is not found or not executable${RESET}"
        exit 1
    fi

    # Set up variables
    LOG_FILE="pdf_shrink_$(date +%Y%m%d_%H%M%S).log"
    ERROR_LOG="pdf_errors_$(date +%Y%m%d_%H%M%S).log"
    
    # Check if we can get the directory size
    if ! ORIGINAL_SIZE=$(du -bs "$INPUT_DIR" | cut -f1); then
        echo -e "${RED}Error: Failed to get directory size${RESET}"
        exit 1
    fi
    
    # Count PDF files
    TOTAL_FILES=$(find "$INPUT_DIR" -type f -name "*.pdf" | wc -l)
    if [ $TOTAL_FILES -eq 0 ]; then
        echo -e "${RED}Error: No PDF files found in $INPUT_DIR${RESET}"
        exit 1
    fi
    
    START_TIME=$(date +%s)

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
        echo -e "Original size: ${MAGENTA}$(numfmt --to=iec-i --suffix=B $ORIGINAL_SIZE)${RESET}"
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
        
        # Find all PDF files and process them in parallel
        find "$INPUT_DIR" -type f -name "*.pdf" -print0 | \
        parallel --null --bar --eta -j "$FILE_PARALLEL_JOBS" --joblog "$ERROR_LOG" \
            "process_pdf {} $MAX_WIDTH $QUALITY $PAGE_PARALLEL_JOBS"
        
        PARALLEL_EXIT_CODE=$?
        if [ $PARALLEL_EXIT_CODE -ne 0 ]; then
            echo -e "${RED}Some files failed to process. Check the error log for details: $ERROR_LOG${RESET}"
        fi

        # Calculate final savings
        if ! FINAL_SIZE=$(du -bs "$INPUT_DIR" | cut -f1); then
            echo -e "${RED}Error: Failed to get final directory size${RESET}"
            exit 1
        fi
        
        TOTAL_SAVED=$((ORIGINAL_SIZE - FINAL_SIZE))
        if [ $ORIGINAL_SIZE -gt 0 ]; then
            TOTAL_SAVED_PERCENT=$((TOTAL_SAVED * 100 / ORIGINAL_SIZE))
        else
            TOTAL_SAVED_PERCENT=0
        fi
        TOTAL_TIME=$(($(date +%s) - START_TIME))
        TOTAL_HOURS=$((TOTAL_TIME / 3600))
        TOTAL_MINS=$(((TOTAL_TIME % 3600) / 60))
        TOTAL_SECS=$((TOTAL_TIME % 60))
        
        if [ $TOTAL_TIME -gt 0 ]; then
            OVERALL_SPEED=$(echo "scale=2; ${TOTAL_SAVED} / 1048576 / ${TOTAL_TIME}" | bc)
        else
            OVERALL_SPEED="N/A"
        fi

        echo -e "${BOLD}===== Final Results =====${RESET}"
        echo -e "Completed: $(date)"
        echo -e "Total processing time: ${YELLOW}${TOTAL_HOURS}h ${TOTAL_MINS}m ${TOTAL_SECS}s${RESET}"
        echo -e "Original size: ${MAGENTA}$(numfmt --to=iec-i --suffix=B $ORIGINAL_SIZE)${RESET}"
        echo -e "Final size: ${MAGENTA}$(numfmt --to=iec-i --suffix=B $FINAL_SIZE)${RESET}"
        echo -e "Total saved: ${GREEN}$(numfmt --to=iec-i --suffix=B $TOTAL_SAVED)${RESET} (${GREEN}$TOTAL_SAVED_PERCENT%${RESET})"
        echo -e "Overall average speed: ${BLUE}${OVERALL_SPEED} MB/s${RESET}"
        echo -e "${BOLD}=======================${RESET}"
    } 2>&1 | tee >(strip_colors > "$LOG_FILE")

    exit 0
}

# Call the main function
main "$@"