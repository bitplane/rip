spawn_tmux() {
  local session_name="$1"
  # Determine project root
  local project_dir
  project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  # If session already exists, attach
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Attaching to existing tmux session: $session_name"
    tmux attach-session -t "$session_name"
    return
  fi

  echo "Creating new tmux session: $session_name"

  # Start tmux with our config file
  tmux -f "$project_dir/scrip/tmux.conf" new-session -d -s "$session_name" -c "$project_dir"
  
  # Attach to the session
  tmux attach-session -t "$session_name"
}