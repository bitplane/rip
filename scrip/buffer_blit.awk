#!/usr/bin/awk -f
# buffer_blit.awk - Blits multiple buffers together based on clip regions

BEGIN {
    FS = "[ \t]+"  # Handle any whitespace in input
    current_line = 0
    buffer_count = 0
}

# First pass: gather all buffer info
{
    # Store buffer path and clipping information
    buffer_path[buffer_count] = $1
    buffer_x[buffer_count] = $2
    buffer_y[buffer_count] = $3
    buffer_w[buffer_count] = $4
    buffer_h[buffer_count] = $5
    
    # Find maximum dimensions to allocate our target buffer
    max_x = (max_x > $2 + $4) ? max_x : $2 + $4
    max_y = (max_y > $3 + $5) ? max_y : $3 + $5
    
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
    
    # Process each buffer in order (assuming they're already sorted correctly)
    for (i = 0; i < buffer_count; i++) {
        # Read the buffer file
        buffer_lines = 0
        while ((getline line < buffer_path[i]) > 0) {
            buffer_content[buffer_lines++] = line
        }
        close(buffer_path[i])
        
        # Get buffer dimensions
        bx = buffer_x[i]
        by = buffer_y[i]
        bw = buffer_w[i]
        bh = buffer_h[i]
        
        # Blit this buffer to the target
        for (y = 0; y < bh && y < buffer_lines; y++) {
            # Split the buffer line by tabs
            split(buffer_content[y], cells, "\t")
            
            for (x = 0; x < bw && x < length(cells); x++) {
                # Only copy non-empty cells
                if (cells[x+1] != "") {
                    result[by + y, bx + x] = cells[x+1]
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