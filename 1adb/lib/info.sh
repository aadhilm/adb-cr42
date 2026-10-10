#!/usr/bin/env bash
# lib/info.sh — phone info

phone_battery()   { echo "=== Battery on $1 ==="; adb -s "$1" shell dumpsys battery; }
phone_memory()    { echo "=== Memory on $1 ==="; adb -s "$1" shell cat /proc/meminfo | head -5; echo; adb -s "$1" shell dumpsys meminfo | head -15; }
phone_cpu()       { echo "=== CPU on $1 ==="; adb -s "$1" shell cat /proc/cpuinfo | grep -E 'processor|model name|BogoMIPS' | head -20; echo; adb -s "$1" shell cat /proc/loadavg; }
phone_storage()   { echo "=== Storage on $1 ==="; adb -s "$1" shell df -h /data /sdcard; }
phone_processes() { echo "=== Processes on $1 ==="; adb -s "$1" shell ps -A | head -40; }

phone_network() {
  echo "=== Network on $1 ==="
  adb -s "$1" shell ip -4 addr show 2>/dev/null | awk '/inet / {print $2, $NF}' | tr -d '\r'
  echo
  adb -s "$1" shell dumpsys wifi 2>/dev/null | grep -oE 'ssid = "[^"]+"' | head -1
}

phone_hardware() {
  local d="$1"
  echo "=== Hardware on $d ==="
  printf 'Model        : %s\n' "$(adb -s "$d" shell getprop ro.product.model | tr -d '\r')"
  printf 'Manufacturer : %s\n' "$(adb -s "$d" shell getprop ro.product.manufacturer | tr -d '\r')"
  printf 'Android      : %s (API %s)\n' \
    "$(adb -s "$d" shell getprop ro.build.version.release | tr -d '\r')" \
    "$(adb -s "$d" shell getprop ro.build.version.sdk | tr -d '\r')"
  printf 'Build        : %s\n' "$(adb -s "$d" shell getprop ro.build.display.id | tr -d '\r')"
  printf 'Serial       : %s\n' "$(adb -s "$d" shell getprop ro.serialno | tr -d '\r')"
  printf 'CPU ABI      : %s\n' "$(adb -s "$d" shell getprop ro.product.cpu.abi | tr -d '\r')"
}

phone_monitor() {
  local d="$1"
  warn "Live monitor on $d — Ctrl-C to stop"
  while :; do
    clear
    echo "=== $d  $(date +%T) ==="
    adb -s "$d" shell top -n 1 -b 2>/dev/null | head -15
    sleep 2
  done
}

phone_save_report() {
  local d="$1"
  local ts; ts=$(date +%Y%m%d-%H%M%S)
  local f="$CR42_REPORTS/phone-info-${d//:/_}-${ts}.txt"
  {
    echo "CR42 ADB Phone Info Report"
    echo "Generated: $(date -Iseconds)"
    echo "Device   : $d"
    echo "-----"
    phone_battery "$d"; echo; phone_memory "$d"; echo; phone_cpu "$d"
    echo; phone_storage "$d"; echo; phone_network "$d"; echo; phone_hardware "$d"
  } > "$f"
  ok "Report saved: $f"
}

menu_info() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Phone Info (devices: ${#DEVICES[@]}) === [mode: ${EXEC_MODE:-sequential}]${c_reset}"
    echo "  1) Battery"
    echo "  2) Memory"
    echo "  3) CPU"
    echo "  4) Storage"
    echo "  5) Running processes"
    echo "  6) Network info"
    echo "  7) Monitor performance (live)"
    echo "  8) Hardware info"
    echo "  9) Save report to file"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1) for_each_device phone_battery;     pause_enter ;;
      2) for_each_device phone_memory;      pause_enter ;;
      3) for_each_device phone_cpu;         pause_enter ;;
      4) for_each_device phone_storage;     pause_enter ;;
      5) for_each_device phone_processes;   pause_enter ;;
      6) for_each_device phone_network;     pause_enter ;;
      7) phone_monitor "${DEVICES[0]}" ;;
      8) for_each_device phone_hardware;    pause_enter ;;
      9) for_each_device phone_save_report; pause_enter ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}
