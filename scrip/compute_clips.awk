#!/usr/bin/awk -f
# compute_clips.awk - Computes visible regions for nested TUI widgets

BEGIN {
    FS = "[ \t]+"  # Handle any whitespace
    HUGE = 65535   # Initial clip size
}

function min(a, b) { return (a < b) ? a : b }
function max(a, b) { return (a > b) ? a : b }

# Extract the widget path from the full path containing .meta/buffer/file
function get_widget_path(full_path) {
    # Find the position of .meta
    meta_pos = index(full_path, ".meta")
    if (meta_pos == 0) return full_path  # No .meta found
    
    # Return everything before .meta
    return substr(full_path, 1, meta_pos - 2)  # -2 to remove the / before .meta
}

# Get parent path from a widget path
function get_parent(path) {
    if (path == "root") return ""
    
    # Find the last '/' in the path
    last_slash = 0
    for (i = 1; i <= length(path); i++) {
        if (substr(path, i, 1) == "/") {
            last_slash = i
        }
    }
    
    # If no slash found, we're at root
    if (last_slash == 0) return "root"
    
    # Return everything before the last slash
    return substr(path, 1, last_slash - 1)
}

# Extract the complete buffer path (.meta/buffer/file and everything after)
function get_buffer_path(full_path) {
    # Find the position of .meta
    meta_pos = index(full_path, ".meta")
    if (meta_pos == 0) return ""  # No .meta found
    
    # Return everything from .meta onwards
    return substr(full_path, meta_pos)
}

{
    full_path = $1
    
    # Widget coordinates and dimensions
    cx = $2; cy = $3; cw = $4; ch = $5
    ox = $6; oy = $7; ow = $8; oh = $9
    
    # Extract the widget path and buffer file
    widget_path = get_widget_path(full_path)
    buffer_path = get_buffer_path(full_path)
    
    if (widget_path == "root") {
        # Root is the first widget - use its coordinates directly
        x = cx
        y = cy
        w = cw
        h = ch
    } else {
        # Get the parent's path
        parent = get_parent(widget_path)
        
        # Check if parent exists and has a valid clip
        if (!(parent in clip_x)) {
            # Parent doesn't exist or was clipped out
            next
        }
        
        # Get parent's clip region
        px = clip_x[parent]
        py = clip_y[parent]
        pw = clip_w[parent]
        ph = clip_h[parent]
        
        # Calculate intersection with parent's clip
        x1 = max(px, cx)
        y1 = max(py, cy)
        x2 = min(px + pw, cx + cw)
        y2 = min(py + ph, cy + ch)
        
        # Calculate dimensions of intersected region
        w = x2 - x1
        h = y2 - y1
        
        # Skip if no intersection
        if (w <= 0 || h <= 0) {
            next
        }
        
        # Set the visible coordinates
        x = x1
        y = y1
    }
    
    # Store this widget's clip region
    clip_x[widget_path] = x
    clip_y[widget_path] = y
    clip_w[widget_path] = w
    clip_h[widget_path] = h
    
    # Output the buffer path and visible region
    # Only output if we have a buffer path
    if (buffer_path != "") {
        printf "%s %d %d %d %d\n", buffer_path, x, y, w, h
    }
}
