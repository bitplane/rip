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

# Ensure a directory is provided as argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 directory_with_pdfs"
    exit 1
fi

# Check if input directory exists
if [ ! -d "$1" ]; then
    echo "Error: $1 is not a valid directory"
    exit 1
fi

# Check if shrink_pdf.sh exists and is executable
if [ ! -x "./shrink_pdf.sh" ]; then
    echo "Error: shrink_pdf.sh is not found or not executable"
    exit 1
fi

# Set up variables
INPUT_DIR="$1"
LOG_FILE="pdf_shrink_$(date +%Y%m%d_%H%M%S).log"
ORIGINAL_SIZE=$(du -bs "$INPUT_DIR" | cut -f1)
TOTAL_FILES=$(find "$INPUT_DIR" -type f -name "*.pdf" | wc -l)
PROCESSED=0
SAVED_TOTAL=0
START_TIME=$(date +%s)
LAST_DIR=""

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
    echo -e "Log file: $LOG_FILE"
    echo -e "${BOLD}==================================${RESET}"
    echo ""

    # Process each PDF file
    find "$INPUT_DIR" -type f -name "*.pdf" -print0 | while IFS= read -r -d $'\0' pdf_file; do
        PROCESSED=$((PROCESSED + 1))
        CURRENT_DIR=$(dirname "$pdf_file")
        FILE_NAME=$(basename "$pdf_file")
        TAR_PATH="${pdf_file%.pdf}.tar"
        
        # Print directory path when changing to a new directory
        if [ "$CURRENT_DIR" != "$LAST_DIR" ]; then
            echo -e "Directory: ${CYAN}$CURRENT_DIR${RESET}"
            LAST_DIR="$CURRENT_DIR"
        fi
        
        echo -e "File ${YELLOW}$PROCESSED${RESET}/${YELLOW}$TOTAL_FILES${RESET}: \"${BOLD}$FILE_NAME${RESET}\""
        
        # Get size before processing
        FILE_SIZE_BEFORE=$(du -b "$pdf_file" | cut -f1)
        
        # Record time before processing
        FILE_START_TIME=$(date +%s)
        
        # Process the PDF file - quote the filename to handle spaces
        ./shrink_pdf.sh "$pdf_file"
        
        # Record time after processing
        FILE_END_TIME=$(date +%s)
        FILE_PROCESS_TIME=$((FILE_END_TIME - FILE_START_TIME))
        
        # Check if tar file was created (successful processing)
        if [ -f "$TAR_PATH" ]; then
            TAR_SIZE=$(du -b "$TAR_PATH" | cut -f1)
            FILE_SAVED=$((FILE_SIZE_BEFORE - TAR_SIZE))
            SAVED_PERCENT=$((FILE_SAVED * 100 / FILE_SIZE_BEFORE))
            SAVED_TOTAL=$((SAVED_TOTAL + FILE_SAVED))
            
            FILE_SPEED=$(echo "scale=2; ${FILE_SIZE_BEFORE} / 1048576 / ${FILE_PROCESS_TIME}" | bc)
            
            echo -e "=> Saved: ${GREEN}$(numfmt --to=iec-i --suffix=B $FILE_SAVED)${RESET} (${GREEN}$SAVED_PERCENT%${RESET})"
            echo -e "=> Processing time: ${YELLOW}${FILE_PROCESS_TIME}s${RESET} (${BLUE}${FILE_SPEED} MB/s${RESET})"
        else
            echo -e "=> ${RED}Unchanged${RESET}: Savings below threshold or processing failed"
        fi
        
        # Calculate average speed so far
        ELAPSED_TIME=$(($(date +%s) - START_TIME))
        if [ $ELAPSED_TIME -gt 0 ]; then
            AVG_SPEED=$(echo "scale=2; ${SAVED_TOTAL} / 1048576 / ${ELAPSED_TIME}" | bc)
            ESTIMATED_REMAINING=$((ELAPSED_TIME * (TOTAL_FILES - PROCESSED) / PROCESSED))
            REMAINING_HOURS=$((ESTIMATED_REMAINING / 3600))
            REMAINING_MINS=$(((ESTIMATED_REMAINING % 3600) / 60))
            
            echo -e "=> Progress: ${YELLOW}$PROCESSED${RESET}/${YELLOW}$TOTAL_FILES${RESET} files processed"
            echo -e "=> Total saved so far: ${GREEN}$(numfmt --to=iec-i --suffix=B $SAVED_TOTAL)${RESET}"
            echo -e "=> Average speed: ${BLUE}${AVG_SPEED} MB/s${RESET}"
            echo -e "=> Estimated time remaining: ${MAGENTA}${REMAINING_HOURS}h ${REMAINING_MINS}m${RESET}"
        else
            echo -e "=> Progress: ${YELLOW}$PROCESSED${RESET}/${YELLOW}$TOTAL_FILES${RESET} files processed"
            echo -e "=> Total saved so far: ${GREEN}$(numfmt --to=iec-i --suffix=B $SAVED_TOTAL)${RESET}"
        fi
        echo ""
    done

    # Calculate final savings
    FINAL_SIZE=$(du -bs "$INPUT_DIR" | cut -f1)
    TOTAL_SAVED=$((ORIGINAL_SIZE - FINAL_SIZE))
    TOTAL_SAVED_PERCENT=$((TOTAL_SAVED * 100 / ORIGINAL_SIZE))
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