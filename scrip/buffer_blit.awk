#!/usr/bin/awk -f
# buffer_blit.awk - Blits multiple buffers together based on clip regions

BEGIN {
    FS = "[ \t]+"  # Handle any whitespace in input
    buffer_count = 0
}

# First pass: gather all buffer info
{
    # Store buffer path and clipping information
    buffer_path[buffer_count] = $1
    
    # Screen position (where to place in output)
    screen_x[buffer_count] = $2
    screen_y[buffer_count] = $3
    
    # Buffer-local coordinates (where to start reading)
    buffer_x[buffer_count] = $4
    buffer_y[buffer_count] = $5
    
    # Dimensions of the visible region
    width[buffer_count] = $6
    height[buffer_count] = $7
    
    # Track maximum dimensions for the target buffer
    max_x = (max_x > $2 + $6) ? max_x : $2 + $6
    max_y = (max_y > $3 + $7) ? max_y : $3 + $7
    
    buffer_count++
}

# Second pass: process all buffers and blit them in order
END {
    if (buffer_count == 0) exit
    
    # Initialize the target buffer with empty cells
    for (y = 0; y < max_y; y++) {
        for (x = 0; x < max_x; x++) {
            result[y, x] = ""
        }
    }
    
    # Process each buffer in order
    for (i = 0; i < buffer_count; i++) {
        # Read the buffer file
        buffer_lines = 0
        while ((getline line < buffer_path[i]) > 0) {
            buffer_content[buffer_lines++] = line
        }
        close(buffer_path[i])
        
        # Get screen position and dimensions
        sx = screen_x[i]
        sy = screen_y[i]
        w = width[i]
        h = height[i]
        
        # Get buffer-local coordinates (offset where to start reading)
        bx = buffer_x[i]
        by = buffer_y[i]
        
        # Blit this buffer to the target
        for (y = 0; y < h && by + y < buffer_lines; y++) {
            # Get the buffer line (adjusted for buffer_y offset)
            buffer_line = by + y
            if (buffer_line < 0 || buffer_line >= buffer_lines) continue
            
            # Split the buffer line by tabs
            split(buffer_content[buffer_line], cells, "\t")
            
            for (x = 0; x < w; x++) {
                # Calculate position in buffer (adjusted for buffer_x offset)
                buffer_col = bx + x
                if (buffer_col < 0 || buffer_col >= length(cells)) continue
                
                # Only copy non-empty cells
                if (cells[buffer_col + 1] != "") {
                    result[sy + y, sx + x] = cells[buffer_col + 1]
                }
            }
        }
    }
    
    # Output the blitted buffer
    for (y = 0; y < max_y; y++) {
        for (x = 0; x < max_x; x++) {
            printf("%s%s", result[y, x], (x < max_x - 1) ? "\t" : "")
        }
        # Only print newline if not the last line
        if (y < max_y - 1) {
            printf("\n")
        }
    }
}