#!/usr/bin/env bash
# lib/connection.sh — select, pair (wireless + USB), connect

PAIR_IP=""

is_device_connected() {
  adb devices | awk 'NR>1 && $2=="device"{print $1}' | grep -qxF "$1"
}

list_usb_devices() {
  adb devices | awk 'NR>1 && $2=="device" && $1 !~ /:/ {print $1}'
}

prompt_ip_port() {
  echo
  echo "${c_bld}Connect mode:${c_reset}"
  echo "  Prefix shortcuts:"
  echo "    1) 192.168.1.x"
  echo "    2) 192.168.x.x"
  echo "    3) Custom IP:PORT"
  echo "    0) Cancel"
  local pfx="" c
  read -rp "Choose: " c
  case "$c" in
    1) pfx="192.168.1." ;;
    2) pfx="192.168."   ;;
    3)
      local custom
      read -rp "Enter IP:PORT: " custom
      if valid_ip_port "$custom"; then REPLY="$custom"; return 0
      else err "Invalid IP:PORT"; return 1; fi
      ;;
    0) return 1 ;;
    *) warn "Invalid choice"; return 1 ;;
  esac
  local last
  read -rp "IP prefix: $pfx — last octet + port (e.g. 5:5555) or 'q': " last
  [ "$last" = "q" ] && return 1
  if [[ "$last" =~ ^([0-9]{1,3}):([0-9]{1,5})$ ]]; then
    REPLY="${pfx}${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
    return 0
  fi
  err "Invalid input (expected 5:5555)"; return 1
}

wireless_pair() {
  local target="$1"
  valid_ip_port "$target" || { err "Invalid IP:PORT"; return 1; }
  read -rp "Pairing code (6 digits): " code
  [ -z "$code" ] && { err "No pairing code"; return 1; }
  log "Pairing with $target ..."
  if adb pair "$target" "$code"; then
    PAIR_IP="${target%%:*}"
    read -rp "Connect port (default 5555): " cp
    [ -z "$cp" ] && cp=5555
    REPLY="${PAIR_IP}:${cp}"
    ok "Paired. Now connecting ..."
    return 0
  fi
  err "Pairing failed"
  return 1
}

usb_pair() {
  echo
  echo "${c_bld}USB pairing${c_reset}"
  echo "[i] Connect device via USB, enable USB debugging, tap 'Allow'."
  echo
  read -rp "Press Enter when cable is connected..." _
  log "Waiting for USB device (up to 20s) ..."
  local waited=0 found=""
  while [ "$waited" -lt 20 ]; do
    found=$(list_usb_devices | head -n1)
    [ -n "$found" ] && break
    sleep 1; waited=$((waited+1))
  done
  if [ -z "$found" ]; then err "No USB device detected"; return 1; fi

  local state
  state=$(adb devices | awk -v d="$found" 'NR>1 && $1==d {print $2}')
  if [ "$state" != "device" ]; then
    warn "State: $state — unlock phone and tap 'Allow'."
    read -rp "Press Enter after authorizing..." _
    state=$(adb devices | awk -v d="$found" 'NR>1 && $1==d {print $2}')
    [ "$state" != "device" ] && { err "Still not authorized."; return 1; }
  fi
  ok "USB device ready: $found"
  REPLY="$found"
  return 0
}

wireless_connect() {
  local target="$1"
  valid_ip_port "$target" || { err "Invalid IP:PORT"; return 1; }
  if is_device_connected "$target"; then
    ok "Already connected: $target"; REPLY="$target"; return 0
  fi
  log "Connecting to $target ..."
  adb connect "$target" >/dev/null 2>&1 || true
  local waited=0
  while [ "$waited" -lt 10 ]; do
    if is_device_connected "$target"; then
      ok "Connected: $target"; REPLY="$target"; return 0
    fi
    sleep 1; waited=$((waited+1))
  done
  err "Could not connect to $target"
  return 1
}

select_device() {
  clear_screen; banner
  echo "${c_bld}=== Connection Menu ===${c_reset}"
  ok "Currently connected:"
  adb devices | awk 'NR>1 && NF>=2 {printf "    %-30s %s\n", $1, $2}'
  echo
  echo "Options:"
  echo "  1) Use already-connected device(s)"
  echo "  2) Connect to a USB/wireless device (adb connect)"
  echo "  3) Pair a new device (wireless or USB)"
  echo "  4) Refresh list"
  echo "  5) Restart ADB service"
  echo "  q) Quit"
  echo

  local ch; read -rp "Choice: " ch
  case "$ch" in
    1)
      mapfile -t all < <(adb devices | awk 'NR>1 && $2=="device"{print $1}')
      [ "${#all[@]}" -eq 0 ] && { err "No devices"; pause_enter; return 1; }
      if [ "${#all[@]}" -eq 1 ]; then
        read -rp "Found 1 device: ${all[0]}. Use it? [Y/n]: " yn
        [[ "$yn" =~ ^[Nn]$ ]] && return 1
        DEVICES=("${all[0]}")
      else
        local i=1
        for d in "${all[@]}"; do printf '  %d) %s\n' "$i" "$d"; i=$((i+1)); done
        read -rp "Select (e.g. 1,3 | a=all): " sel
        if [ "$sel" = "a" ]; then DEVICES=("${all[@]}")
        else
          local picked=()
          IFS=',' read -ra nums <<< "$sel"
          for n in "${nums[@]}"; do
            [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#all[@]} )) \
              && picked+=("${all[$((n-1))]}")
          done
          DEVICES=("${picked[@]}")
        fi
      fi
      prompt_execution_mode
      ;;
    2)
      while :; do
        prompt_ip_port || break
        wireless_connect "$REPLY" || continue
        DEVICES+=("$REPLY")
        read -rp "Add more devices? [y/N]: " more
        [[ "$more" =~ ^[Yy]$ ]] || break
      done
      prompt_execution_mode
      ;;
    3)
      echo
      echo "${c_bld}Pair a new device${c_reset}"
      echo "  1) Wireless — enter pairing code"
      echo "  2) USB — authorize via cable"
      echo "  0) Cancel"
      echo
      local pc; read -rp "Choice: " pc
      case "$pc" in
        1)
          while :; do
            prompt_ip_port || break
            wireless_pair "$REPLY" || continue
            wireless_connect "$REPLY" && DEVICES+=("$REPLY")
            read -rp "Add more devices? [y/N]: " more
            [[ "$more" =~ ^[Yy]$ ]] || break
          done
          ;;
        2)
          usb_pair || { pause_enter; return 1; }
          DEVICES+=("$REPLY")
          read -rp "Add more devices? [y/N]: " more
          [[ "$more" =~ ^[Yy]$ ]] && { usb_pair && DEVICES+=("$REPLY"); }
          ;;
        0) return 1 ;;
        *) warn "Invalid"; return 1 ;;
      esac
      prompt_execution_mode
      ;;
    4) return 2 ;;
    5)
      read -rp "Restart ADB service? [y/N]: " yn
      [[ "$yn" =~ ^[Yy]$ ]] || return 1
      adb kill-server; adb start-server
      ok "ADB restarted"; pause_enter; return 2
      ;;
    q|Q) session_summary; exit 0 ;;
    *) return 1 ;;
  esac

  [ "${#DEVICES[@]}" -gt 0 ] && { ok "Selected ${#DEVICES[@]} device(s)"; pause_enter; return 0; }
  return 1
}
