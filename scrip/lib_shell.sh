# Add an exit handler to this pid
# Usage: shell_trap "command goes here"
shell_trap() {
    local name="_SHELL_EXIT_$$"
    if ! declare -p "$name" &>/dev/null; then
        declare -g -a "$name"
        trap __shell_exit EXIT INT TERM HUP
    fi

    local -n stack="$name"
    [[ -n "$1" ]] && stack+=("$1")
}

# called internally when the shell exits
__shell_exit() {
    local name="_SHELL_EXIT_$$"

    # Skip if not defined
    declare -p "$name" &>/dev/null || return

    local -n stack="$name"
    for fn in "${stack[@]}"; do
        eval "$fn" || true
    done
}
