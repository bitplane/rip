#!/bin/bash

#
# Hooks for metadata changes
#

# When the ddrescue log is added, it adds the integrity field
meta_hook_ddrescue.log() {
    (
    awk '
    /^0x/ {
        size   =  strtonum($2)
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
