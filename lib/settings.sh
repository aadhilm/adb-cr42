#!/usr/bin/env bash
# lib/settings.sh

settings_write() {
  cat > "$CR42_CONFIG" << EOF
EXEC_MODE=$EXEC_MODE
COOLDOWN=$COOLDOWN
WAIT_AFTER_TRIES=$WAIT_AFTER_TRIES
CHAIN_STEP_WAIT=$CHAIN_STEP_WAIT
KEYEVENT_SLEEP=$KEYEVENT_SLEEP
NOTIFY=$NOTIFY
TELEGRAM_TOKEN=$TELEGRAM_TOKEN
TELEGRAM_CHAT=$TELEGRAM_CHAT
HARD_REFRESH=$HARD_REFRESH
NO_BANNER=$NO_BANNER
EOF
  ok "Saved $CR42_CONFIG"
}

menu_settings() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Settings ===${c_reset}"
    echo "  1) Execution mode  [${EXEC_MODE:-sequential}]"
    echo "  2) Default cooldown [${COOLDOWN}]"
    echo "  3) Chain step wait  [${CHAIN_STEP_WAIT}s]"
    echo "  4) Notifications    [${NOTIFY:-none}]"
    echo "  5) Telegram token   [$( [ -n "${TELEGRAM_TOKEN:-}" ] && echo set || echo empty )]"
    echo "  6) Telegram chat    [${TELEGRAM_CHAT:-empty}]"
    echo "  7) Save as defaults"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1) read -rp "Mode (sequential/parallel): " m
         [[ "$m" =~ ^(sequential|parallel)$ ]] && EXEC_MODE="$m" && export EXEC_MODE ;;
      2) read -rp "Cooldown seconds (0=skip): " v
         [[ "$v" =~ ^[0-9]+$ ]] && COOLDOWN="$v" && export COOLDOWN ;;
      3) read -rp "Chain step wait: " v
         [[ "$v" =~ ^[0-9]+$ ]] && CHAIN_STEP_WAIT="$v" && export CHAIN_STEP_WAIT ;;
      4) read -rp "Notify (none/desktop/telegram/both): " v
         [[ "$v" =~ ^(none|desktop|telegram|both)$ ]] && NOTIFY="$v" && export NOTIFY ;;
      5) read -rp "Telegram token: " v; TELEGRAM_TOKEN="$v"; export TELEGRAM_TOKEN ;;
      6) read -rp "Telegram chat id: " v; TELEGRAM_CHAT="$v"; export TELEGRAM_CHAT ;;
      7) settings_write; pause_enter ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}
