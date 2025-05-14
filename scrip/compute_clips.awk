#!/usr/bin/awk -f
BEGIN { FS = "[ \t]+" }

function get_widget_path(p) { meta_pos = index(p, "/.meta/"); return meta_pos ? substr(p, 1, meta_pos - 1) : p }
function get_parent(p) { last_slash = match(p, ".*\\/"); return last_slash ? substr(p, 1, RLENGTH - 1) : p }
function max(a, b) { return a > b ? a : b }
function min(a, b) { return a < b ? a : b }

{
  path = get_widget_path($1)
  parent = get_parent(path)
  
  # Calculate absolute position
  abs_x[path] = abs_x[parent] + $2  
  abs_y[path] = abs_y[parent] + $3  
  
  # Widget boundaries in absolute coordinates
  widget_x1 = abs_x[path]
  widget_y1 = abs_y[path]
  widget_x2 = widget_x1 + $4
  widget_y2 = widget_y1 + $5
  
  # Clip with parent's clip region
  clip_x1[path] = max(widget_x1, clip_x1[parent])
  clip_y1[path] = max(widget_y1, clip_y1[parent])
  clip_x2[path] = min(widget_x2, clip_x2[parent] ? clip_x2[parent] : 9999)
  clip_y2[path] = min(widget_y2, clip_y2[parent] ? clip_y2[parent] : 9999)
  
  # Skip if no intersection
  if (clip_x2[path] <= clip_x1[path] || clip_y2[path] <= clip_y1[path]) next
  
  # Output for buffer paths
  if (index($1, "/.meta/") > 0) {
    # Screen coordinates (where to place on screen)
    screen_x = clip_x1[path]
    screen_y = clip_y1[path]
    
    # Buffer-local coordinates (where to start in buffer)
    buffer_x = clip_x1[path] - abs_x[path]
    buffer_y = clip_y1[path] - abs_y[path]
    
    # Dimensions of visible region
    width = clip_x2[path] - clip_x1[path]
    height = clip_y2[path] - clip_y1[path]
    
    # Output all 7 columns
    printf "%s %d %d %d %d %d %d\n", $1, 
           screen_x, screen_y, 
           buffer_x, buffer_y, 
           width, height
  }
}