#!/bin/bash

#
# Hooks for metadata changes
#

# When the ddrescue log is added, it adds the integrity field
meta_hook_ddrescue.log() {
    (
    awk '
    function hex2dec(h,  n, i, c, v) {
        h = tolower(h); sub(/^0x/, "", h); n = 0
        for (i = 1; i <= length(h); i++) {
            c = substr(h, i, 1)
            v = index("0123456789abcdef", c) - 1
            n = n * 16 + v
        }
        return n
    }
    /^0x/ {
        size   = hex2dec($2)
        total  += size
        if ($3 == "+") good += size
    }
    END {
        if (total == 0) { print 0; exit }
        percent = int((good * 100) / total)
        print percent
    }' || echo 0
    ) | meta_set ddrescue.integrity "$2" "$3"
}

