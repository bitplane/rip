spawn_tmux_session() {
  session_name="$1"

  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Attaching to existing tmux session: $session_name"
    tmux attach-session -t "$session_name"
    return
  fi

  echo "Creating new tmux session: $session_name"

  tmux new-session -d -s "$session_name" -n 'archive'

  tmux send-keys -t "$session_name" 'cd ~/image/scrip && ./watch.sh' C-m
  tmux split-window -v -t "$session_name"
  tmux send-keys -t "$session_name" 'cd ~/image/scrip && ./1.rip.sh' C-m
  tmux split-window -h -t "$session_name"
  tmux send-keys -t "$session_name" 'cd ~/image/scrip && ./2.zip.sh' C-m
  tmux select-pane -t 0
  tmux split-window -h -t "$session_name"
  tmux send-keys -t "$session_name" 'cd ~/image/scrip && ./3.ship.sh' C-m

  tmux select-pane -t 0
  tmux attach-session -t "$session_name"
}
