show_latest_line() {
    local pre="$1"
    echo
    while IFS= read -r line; do
        printf "\033[A\033[2K%s\n" "${pre}$line"
    done
    echo
}

