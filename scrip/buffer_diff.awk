#!/usr/bin/awk -f
BEGIN { 
    FS = OFS = "\t"
    cx = cy = -1  # Invalid initial position forces first cursor move
    pen = "\033[0m"  # Start with default style
    printf "%s\033[?25l", pen  # Reset and hide cursor while updating
}

# First file - store old content
NR == FNR { 
    old[FNR] = $0
    for(i=1; i<=NF; i++) {
        o[FNR,i] = $i
    }
    next 
}

# Second file - compare and update
{
    for(i=1; i<=NF; i++) {
        if(o[FNR,i] != $i) {
            # Extract style and character
            if ($i ~ /^\033/) {
                # Handle potentially multiple style codes
                last_m = 0
                for (j=1; j<=length($i); j++) {
                    if (substr($i, j, 1) == "m") last_m = j
                    if (substr($i, j, 1) != "\033" && last_m > 0 && 
                        !(substr($i, j-1, 1) ~ /[0-9;]/)) break
                }
                style = substr($i, 1, last_m)
                char = substr($i, last_m+1)
            } else {
                style = ""
                char = $i
            }
            
            # Move cursor if needed
            if(cx != i || cy != FNR) { 
                printf "\033[%d;%dH", FNR, i
                cx = i
                cy = FNR 
            }
            
            # Update style if changed
            if(pen != style) { 
                printf "%s", style
                pen = style 
            }
            
            # Print the character
            printf "%s", char
            cx = i + 1  # Move cursor forward by the width of what we printed
        }
    }
}

END {
    printf "\033[%s\033[?25h", pen  # Reset style and show cursor
}