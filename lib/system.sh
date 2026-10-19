#!/usr/bin/env bash
# lib/system.sh — brightness, volume, reboot, lock

sys_brightness() {
  local d="$1"
  local cur; cur=$(adb -s "$d" shell settings get system screen_brightness | tr -d '\r')
  echo "Current: $cur"
  read -rp "New value 0-255 (Enter to keep): " v
  [ -n "$v" ] && adb -s "$d" shell settings put system screen_brightness "$v" && ok "Brightness set"
}

sys_volume() {
  local d="$1"
  read -rp "Volume 0-15: " v
  [[ "$v" =~ ^[0-9]+$ ]] || return
  adb -s "$d" shell media volume --show --stream 3 --set "$v" >/dev/null 2>&1
  ok "Volume = $v"
}

sys_timeout() {
  local d="$1"
  read -rp "Timeout ms: " v
  [[ "$v" =~ ^[0-9]+$ ]] || return
  adb -s "$d" shell settings put system screen_off_timeout "$v"
  ok "Timeout set"
}

sys_airplane() {
  local d="$1"
  read -rp "Airplane ON? [y/n]: " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    adb -s "$d" shell settings put global airplane_mode_on 1
    adb -s "$d" shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1
    ok "Airplane ON"
  else
    adb -s "$d" shell settings put global airplane_mode_on 0
    adb -s "$d" shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false >/dev/null 2>&1
    ok "Airplane OFF"
  fi
}

sys_reboot() {
  local d="$1"
  echo "  1) normal  2) recovery  3) bootloader  0) cancel"
  local c; read -rp "Choice: " c
  case "$c" in
    1) adb -s "$d" reboot ;;
    2) adb -s "$d" reboot recovery ;;
    3) adb -s "$d" reboot bootloader ;;
    0) return ;;
  esac
  ok "Reboot sent"
}

sys_shutdown() { adb -s "$1" shell su -c "reboot -p" 2>/dev/null || adb -s "$1" shell reboot -p 2>/dev/null || err "Failed (root?)"; }
sys_lock()     { adb -s "$1" shell input keyevent 26 >/dev/null 2>&1; ok "Locked"; }

menu_system() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== System (devices: ${#DEVICES[@]}) === [mode: ${EXEC_MODE:-sequential}]${c_reset}"
    echo "  1) Brightness"
    echo "  2) Volume"
    echo "  3) Screen timeout"
    echo "  4) Airplane mode toggle"
    echo "  5) Reboot"
    echo "  6) Shutdown (root)"
    echo "  7) Lock screen"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1) for_each_device sys_brightness; pause_enter ;;
      2) for_each_device sys_volume;     pause_enter ;;
      3) for_each_device sys_timeout;    pause_enter ;;
      4) for_each_device sys_airplane;   pause_enter ;;
      5) for_each_device sys_reboot;     pause_enter ;;
      6) for_each_device sys_shutdown;   pause_enter ;;
      7) for_each_device sys_lock;       pause_enter ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}

