#!/bin/bash
# Configurable settings
MAX_WIDTH=1280    # Maximum width for images (pixels)
QUALITY=50        # WebP compression quality (0-100)
PARALLEL_JOBS=8   # Number of parallel jobs (half your cores is a good starting point)

# Ensure a PDF file is provided as argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 input.pdf"
    exit 1
fi

# Check if input file exists and is a PDF
if [ ! -f "$1" ] || [[ $(file -b --mime-type "$1") != "application/pdf" ]]; then
    echo "Error: $1 is not a valid PDF file"
    exit 1
fi

# Check if GNU parallel is installed
if ! command -v parallel &> /dev/null; then
    echo "Error: GNU parallel is not installed. Please install it first."
    exit 1
fi

# Set up variables
INPUT_PDF="$1"
PDF_DIR=$(dirname "$INPUT_PDF")
BASE_NAME=$(basename "$INPUT_PDF")
TEMP_DIR="${BASE_NAME}.files"
ARCHIVE="${PDF_DIR}/${BASE_NAME%.pdf}.tar"
ORIGINAL_SIZE=$(du -b "$INPUT_PDF" | cut -f1)
ORIGINAL_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B $ORIGINAL_SIZE)

echo "Settings: MAX_WIDTH=$MAX_WIDTH, QUALITY=$QUALITY, PARALLEL_JOBS=$PARALLEL_JOBS"
echo "File: $BASE_NAME ($ORIGINAL_SIZE_HUMAN)"
echo " - Extracting to $TEMP_DIR"

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Extract images
pdfimages -all "$INPUT_PDF" "$TEMP_DIR/img"

# Check if any images were extracted
if [ ! "$(ls -A $TEMP_DIR)" ]; then
    echo " - No images found in PDF. Nothing to compress."
    rmdir "$TEMP_DIR"
    exit 0
fi

# Create a conversion function to be passed to parallel
convert_image() {
    local img="$1"
    local max_width="$2"
    local quality="$3"
    
    # Skip if not a regular file
    [ -f "$img" ] || return
    
    # Get width safely with error handling
    WIDTH=$(identify -format "%w" "$img" 2>/dev/null || echo "0")
    
    # Skip if we couldn't get width
    if [ -z "$WIDTH" ] || [ "$WIDTH" = "0" ]; then
        return
    fi
    
    if [ "$WIDTH" -gt "$max_width" ]; then
        cwebp -q "$quality" -resize "$max_width" 0 "$img" -o "${img}.webp" &>/dev/null
    else
        cwebp -q "$quality" "$img" -o "${img}.webp" &>/dev/null
    fi
}

# Export the function so parallel can see it
export -f convert_image

# Process images in parallel
echo " - Processing images in parallel (using $PARALLEL_JOBS jobs)..."
find "$TEMP_DIR" -type f | parallel -j "$PARALLEL_JOBS" "convert_image {} $MAX_WIDTH $QUALITY"

# Remove original files, keeping only WebPs
find "$TEMP_DIR" -type f ! -name "*.webp" -delete

# Calculate new size
NEW_SIZE=$(du -b "$TEMP_DIR" | cut -f1)
NEW_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B $NEW_SIZE)
SAVED_BYTES=$((ORIGINAL_SIZE - NEW_SIZE))
SAVED_BYTES_HUMAN=$(numfmt --to=iec-i --suffix=B $SAVED_BYTES)
SAVED_PERCENT=$((SAVED_BYTES * 100 / ORIGINAL_SIZE))

echo " - Compression results:"
echo "   - Original size: $ORIGINAL_SIZE_HUMAN, new size: $NEW_SIZE_HUMAN, saved: $SAVED_BYTES_HUMAN ($SAVED_PERCENT%)"

# Check if savings are worth it (< 25%)
if [ $SAVED_PERCENT -lt 25 ]; then
    echo " - Space savings less than 25%. Keeping original PDF."
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Create archive
echo " - Archiving compressed images"
tar -cf "$ARCHIVE" -C "$TEMP_DIR" .

# Clean up
rm -rf "$TEMP_DIR"
rm "$INPUT_PDF"

echo " - Replaced $BASE_NAME with ${BASE_NAME%.pdf}.tar"
echo ""
exit 0
