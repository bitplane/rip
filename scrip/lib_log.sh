BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGFILE="$BASE_DIR/archive.log"

log() {
  local message="$1"
  local timestamped="$(date '+%Y-%m-%d %H:%M:%S') "[$$]" $message"
  echo "$timestamped" >> "$LOGFILE"
  echo "$message"
}

log_info() {
  local message="$1"
  log "[I]: $message"
}

log_error() {
  local message="$1"
  log "[E]: $message" >&2
}

log_alert() {
  local message="$1"
  log_error "$message"
  
  if command -v notify-send &>/dev/null; then
    notify-send "Archive Pipeline Alert" "$message"
  fi
}
