#!/usr/bin/env bash
#
# cr42-adb.sh — CR42 ADB Toolkit
# Educational / authorized-testing use only.
#
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CR42_ROOT="$SCRIPT_DIR"
export CR42_LIB="$SCRIPT_DIR/lib"
export CR42_CHAINS="$SCRIPT_DIR/chains"
export CR42_LOGS="$SCRIPT_DIR/logs"
export CR42_SHOTS="$SCRIPT_DIR/shots"
export CR42_REPORTS="$SCRIPT_DIR/reports"
export CR42_STATE="$SCRIPT_DIR/state.json"
export CR42_CONFIG="$HOME/.cr42-adb.conf"
export CR42_ACK="$HOME/.cr42-adb.ack"

mkdir -p "$CR42_CHAINS" "$CR42_LOGS" "$CR42_SHOTS" "$CR42_REPORTS"

source "$CR42_LIB/common.sh"
source "$CR42_LIB/validation.sh"

CLI_NO_BANNER=0
CLI_DRY_RUN=0
CLI_MODE=""

print_help() {
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║  CR42 ADB TOOLKIT — Educational Use Only                         ║
╠══════════════════════════════════════════════════════════════════╣
║  Only use on devices YOU OWN or have WRITTEN AUTHORIZATION       ║
║  to test. Unauthorized access is illegal in most countries.      ║
╚══════════════════════════════════════════════════════════════════╝

USAGE
  cr42-adb.sh [options]

OPTIONS
  -d, --device <ip:port>     Connect to a device
      --sequential           Run tasks one device at a time
      --parallel             Run tasks on all devices at once
      --dry-run              Print adb commands without executing
      --no-banner            Skip the ASCII banner
  -h, --help
      --version

LEGAL
  Educational / authorized-testing use only.
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)       print_help; exit 0 ;;
      --version)       echo "cr42-adb $VERSION"; exit 0 ;;
      -d|--device)     CLI_DEVICE="${2:-}"; shift 2 ;;
      --parallel)      CLI_MODE="parallel"; shift ;;
      --sequential)    CLI_MODE="sequential"; shift ;;
      --dry-run)       CLI_DRY_RUN=1; shift ;;
      --no-banner)     CLI_NO_BANNER=1; shift ;;
      --) shift; break ;;
      -*) err "Unknown option: $1"; exit 2 ;;
      *) break ;;
    esac
  done
  [ "$CLI_DRY_RUN" -eq 1 ] && export DRY_RUN=1
  [ -n "$CLI_MODE" ] && export EXEC_MODE="$CLI_MODE"
}

first_run_warning() {
  [ -f "$CR42_ACK" ] && return 0
  clear_screen
  cat << 'EOF'

╔══════════════════════════════════════════════════════════════════╗
║  FIRST RUN — PLEASE READ                                         ║
╠══════════════════════════════════════════════════════════════════╣
║  You may ONLY use this tool on:                                  ║
║    • Devices you personally own                                  ║
║    • Devices you have WRITTEN AUTHORIZATION to test              ║
║    • Isolated lab / test devices in a controlled environment     ║
║                                                                  ║
║  Unauthorized access is a criminal offense in most jurisdictions ║
╚══════════════════════════════════════════════════════════════════╝

EOF
  printf 'Type %sI UNDERSTAND%s to accept: ' "$c_bld" "$c_reset"
  local ack; read -r ack
  if [ "$ack" = "I UNDERSTAND" ]; then
    echo "Acknowledged at $(date -Iseconds)" > "$CR42_ACK"
    ok "Acknowledgment saved."
  else
    err "Not acknowledged."; exit 1
  fi
}

source_modules() {
  local m
  for m in connection parallel menus actions info brute screen network \
           media file system logcat settings notify report; do
    local f="$CR42_LIB/$m.sh"
    if [ -f "$f" ]; then
      # shellcheck disable=SC1090
      source "$f"
    else
      warn "Missing module: lib/$m.sh"
    fi
  done
}

load_config() {
  [ -f "$CR42_CONFIG" ] && source "$CR42_CONFIG"
  export EXEC_MODE="${EXEC_MODE:-}"
  export COOLDOWN="${COOLDOWN:-15}"
  export WAIT_AFTER_TRIES="${WAIT_AFTER_TRIES:-3}"
  export CHAIN_STEP_WAIT="${CHAIN_STEP_WAIT:-10}"
  export KEYEVENT_SLEEP="${KEYEVENT_SLEEP:-1}"
  export CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-10}"
  export NOTIFY="${NOTIFY:-none}"
  export HARD_REFRESH="${HARD_REFRESH:-0}"
  export NO_BANNER="${NO_BANNER:-0}"
  export TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
  export TELEGRAM_CHAT="${TELEGRAM_CHAT:-}"
}

SESSION_START=$(date +%s)
ACTION_COUNT=0
DEVICES=()

session_summary() {
  local elapsed=$(( $(date +%s) - SESSION_START ))
  local h=$(( elapsed / 3600 ))
  local m=$(( (elapsed % 3600) / 60 ))
  local s=$(( elapsed % 60 ))
  local tstr
  tstr=$(printf '%02d:%02d:%02d' "$h" "$m" "$s")
  local dcount="${#DEVICES[@]}"

  echo
  printf '%s[*]%s Session: %s   Devices: %s   Actions: %s\n' \
    "$c_cyn" "$c_reset" "$tstr" "$dcount" "$ACTION_COUNT"
  if [ -d "${LOG_DIR:-}" ]; then
    printf '%s[*]%s Logs saved: %s\n' "$c_cyn" "$c_reset" "$LOG_DIR"
  fi
  echo "Goodbye."
}

cleanup() {
  local rc=$?
  echo
  warn "Cleaning up ..."
  jobs -p 2>/dev/null | xargs -r kill 2>/dev/null
  if [ "${#DEVICES[@]}" -gt 0 ]; then
    local d
    for d in "${DEVICES[@]}"; do
      adb -s "$d" shell pkill screenrecord >/dev/null 2>&1
    done
  fi
  session_summary
  exit "$rc"
}
trap cleanup INT TERM

main() {
  parse_args "$@"
  load_config
  source_modules

  [ "$CLI_NO_BANNER" -eq 1 ] || [ "${NO_BANNER:-0}" = "1" ] || banner
  first_run_warning

  command -v adb >/dev/null 2>&1 || { err "adb not found in PATH"; exit 1; }

  local session_dir="$CR42_LOGS/$(date +%Y-%m-%d_%H-%M-%S)"
  mkdir -p "$session_dir"
  export LOG_DIR="$session_dir"
  report_init

  main_loop
}

main "$@"
