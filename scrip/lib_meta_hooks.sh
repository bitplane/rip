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

# prefix dir name with path when we add a date
meta_hook_date() {
    local path date oldname wd in_working_dir
    echo "All arguments: $@"
    path="$(fs_path "$3")"
    date="$(cat | tr '-' '_')"
    oldname=$(basename "$3")
    if [[ "${oldname:0:${#date}}" != "$date" ]]; then
        newname="$date"_"$oldname"
        
        # if we're in this dir
        wd=$(pwd)
        if [[ "${wd:0:${#path}}" = "$path" ]]; then
            cd ..
            in_working_dir=true
        fi

        mv "$path" "$(dirname "$path")"/"$newname"

        if [[ "$in_working_dir" == "true" ]]; then
            cd "$newname"
            cd . # fuck you bash
        fi
    fi
}
