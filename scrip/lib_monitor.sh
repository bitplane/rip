monitor_log() {
  local logfile="$1"
  if [[ -f "$logfile" ]]; then
    tail -n 5 "$logfile"
  else
    echo "(No log yet)"
  fi
}

monitor_queue() {
  local base_dir="$1"
  for queue in "$base_dir"/?.*; do
    count=$(find "$base_dir/$queue" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    printf "%-15s: %s\n" "$queue" "$count"
  done
}

monitor_tmux() {
  local session_name="$1"

  # If session already exists, attach
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Attaching to existing tmux session: $session_name"
    tmux attach-session -t "$session_name"
    return
  fi

  echo "Creating new tmux session: $session_name"

  # Start tmux with our config file
  tmux -f "$BASE_DIR/scrip/tmux.conf" new-session -d -s "$session_name" -c "$BASE_DIR"
  
  # Attach to the session
  tmux attach-session -t "$session_name"
}