#!/usr/bin/awk -f
BEGIN { FS = OFS = "\t"; cx = cy = -1; pen = "\033[0m"; print pen }
NR == FNR { old[FNR] = $0; for(i=1; i<=NF; i++) { o[FNR,i] = $i; } next }

{
  for(i=1; i<=NF; i++) {
    if(o[FNR,i] != $i) {
      # Extract style and char (adjust based on your format)
      style = ($i ~ /^\033/) ? substr($i, 1, index($i, "m")) : ""
      char = ($i ~ /^\033/) ? substr($i, index($i, "m")+1) : $i
      
      # Update position if needed
      if(cx != i || cy != FNR) { printf "\033[%d;%dH", FNR, i; cx = i; cy = FNR }
      
      # Update style if needed
      if(pen != style) { printf "%s", style; pen = style }
      
      # Print the character
      printf "%s", char
      cx++  # Update cursor position after printing
    }
  }
}