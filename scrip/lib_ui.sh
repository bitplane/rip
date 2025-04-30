show_latest_line() {
  echo
  while IFS= read -r line; do
    printf "\033[A\033[2K%s\n" "$line"
  done
  echo
}

