#!/usr/bin/env bash
# lib/notify.sh

notify_desktop() {
  command -v notify-send >/dev/null 2>&1 && notify-send "$1" "$2"
}

notify_telegram() {
  [ -z "${TELEGRAM_TOKEN:-}" ] && return 1
  [ -z "${TELEGRAM_CHAT:-}" ]  && return 1
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT}" -d "text=$1" >/dev/null 2>&1
}

notify() {
  local msg="$1"
  case "${NOTIFY:-none}" in
    desktop)  notify_desktop "CR42 ADB" "$msg" ;;
    telegram) notify_telegram "$msg" ;;
    both)     notify_desktop "CR42 ADB" "$msg"; notify_telegram "$msg" ;;
  esac
}
