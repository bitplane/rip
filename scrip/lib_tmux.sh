spawn_tmux() {
  local session_name="$1"
  # Determine project root (one level up from this script)
  local project_dir
  project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  # If session already exists, attach
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Attaching to existing tmux session: $session_name"
    tmux attach-session -t "$session_name"
    return
  fi

  echo "Creating new tmux session: $session_name"

  # Start detached session in project root, window named "watch"
  tmux new-session -d -s "$session_name" -c "$project_dir" -n watch

  # Pane 0: watcher
  tmux send-keys -t "$session_name":watch.0 \
    "./scrip/watch.sh" C-m

  # Pane 1: rip
  tmux split-window -v -t "$session_name":watch.0 -c "$project_dir"
  tmux send-keys -t "$session_name":watch.1 \
    "./scrip/1.rip.sh" C-m

  # Pane 2: snip
  tmux split-window -h -t "$session_name":watch.1 -c "$project_dir"
  tmux send-keys -t "$session_name":watch.2 \
    "./scrip/2.snip.sh" C-m

  # Pane 3: zip
  tmux split-window -h -t "$session_name":watch.0 -c "$project_dir"
  tmux send-keys -t "$session_name":watch.3 \
    "./scrip/3.zip.sh" C-m

  # Pane 4: ship
  tmux split-window -h -t "$session_name":watch.3 -c "$project_dir"
  tmux send-keys -t "$session_name":watch.4 \
    "./scrip/4.ship.sh" C-m

  # Even out the pane layout
  tmux select-layout -t "$session_name" tiled

  # Attach to the session
  tmux attach-session -t "$session_name"
}
