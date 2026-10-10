#!/usr/bin/env bash
# lib/network.sh — network info + advanced (proxy / forward / tcpip)

net_show() {
  local dev="$1"
  echo "=== Network on $dev ==="
  local ips
  ips=$(adb -s "$dev" shell ip -4 addr show 2>/dev/null \
        | awk '/inet / {print $2, $NF}' | tr -d '\r')
  printf '%-20s %s\n' "Interface" "IP"
  printf '%-20s %s\n' "---------" "--"
  [ -n "$ips" ] && echo "$ips" | while read -r ip iface; do
    printf '%-20s %s\n' "$iface" "$ip"
  done

  local ssid
  ssid=$(adb -s "$dev" shell dumpsys wifi 2>/dev/null \
         | grep -oE 'ssid = "[^"]+"' | head -1 | sed 's/ssid = //; s/"//g' | tr -d '\r')
  printf '\n%-20s %s\n' "Wi-Fi SSID" "${ssid:-<none>}"

  local mac
  mac=$(adb -s "$dev" shell ip link show wlan0 2>/dev/null \
        | awk '/link\/ether/ {print $2}' | tr -d '\r')
  printf '%-20s %s\n' "Wi-Fi MAC" "${mac:-<unknown>}"

  local gw
  gw=$(adb -s "$dev" shell ip route 2>/dev/null \
       | awk '/default/ {print $3}' | head -1 | tr -d '\r')
  printf '%-20s %s\n' "Gateway" "${gw:-<unknown>}"
}

net_ping_trace() {
  local dev="$1"
  read -rp "Host [8.8.8.8]: " host
  [ -z "$host" ] && host=8.8.8.8
  echo "--- ping ---"
  adb -s "$dev" shell ping -c 4 "$host"
  echo "--- traceroute ---"
  adb -s "$dev" shell traceroute -m 10 "$host" 2>/dev/null \
    || adb -s "$dev" shell busybox traceroute -m 10 "$host" 2>/dev/null \
    || warn "traceroute not available"
}

net_set_proxy()   { local d="$1"; read -rp "Proxy host:port: " p; [ -n "$p" ] && { adb -s "$d" shell settings put global http_proxy "$p"; ok "Proxy set"; }; }
net_clear_proxy() { local d="$1"; adb -s "$d" shell settings put global http_proxy :0; ok "Proxy cleared"; }
net_forward() {
  local d="$1"; read -rp "Local port: " lp; read -rp "Remote port: " rp
  adb -s "$d" forward "tcp:$lp" "tcp:$rp"; ok "Forwarded"
}
net_reverse() {
  local d="$1"; read -rp "Device port: " dp; read -rp "Host port: " hp
  adb -s "$d" reverse "tcp:$dp" "tcp:$hp"; ok "Reversed"
}
net_tcpip() { adb -s "$1" tcpip 5555 && ok "tcpip 5555 enabled"; }

menu_network_advanced() {
  local dev="${DEVICES[0]}"
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Network Advanced ($dev) ===${c_reset}"
    echo "  1) Set HTTP proxy"
    echo "  2) Clear proxy"
    echo "  3) Port forward (host → device)"
    echo "  4) Reverse forward (device → host)"
    echo "  5) Enable adb over TCP (tcpip 5555)"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1) net_set_proxy   "$dev"; pause_enter ;;
      2) net_clear_proxy "$dev"; pause_enter ;;
      3) net_forward     "$dev"; pause_enter ;;
      4) net_reverse     "$dev"; pause_enter ;;
      5) net_tcpip       "$dev"; pause_enter ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}

menu_network() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Network / Proxy (devices: ${#DEVICES[@]}) === [mode: ${EXEC_MODE:-sequential}]${c_reset}"
    echo "  1) Show IP / MAC / Wi-Fi details"
    echo "  2) Ping and traceroute from device"
    echo "  3) Advanced (proxy / forward / tcpip)"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1) for_each_device net_show;       pause_enter ;;
      2) for_each_device net_ping_trace; pause_enter ;;
      3) menu_network_advanced ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}

