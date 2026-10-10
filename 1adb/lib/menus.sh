#!/usr/bin/env bash
# lib/menus.sh — top-level dispatch

main_loop() {
  while :; do
    select_device
    rc=$?
    if [ "$rc" -eq 2 ]; then continue; fi
    if [ "$rc" -ne 0 ]; then
      read -rp "Retry? [y/N]: " yn
      [[ "$yn" =~ ^[Yy]$ ]] || { session_summary; exit 0; }
      continue
    fi
    main_menu
  done
}

main_menu() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Main Menu ===${c_reset}  [devices: ${#DEVICES[@]}]  [mode: ${EXEC_MODE:-sequential}]"
    echo
    echo "   1) Phone info"
    echo "   2) Brute force"
    echo "   3) Launch / open app or website"
    echo "   4) Communication (call / SMS)"
    echo "   5) Device Screen & Camera / Mic"
    echo "   6) Network / Proxy"
    echo "   7) Media control"
    echo "   8) File transfer"
    echo "   9) System"
    echo "  10) Multiple action (chain)"
    echo "  11) Live log"
    echo "  12) Settings"
    echo "   0) Back to connection menu"
    echo "   q) Quit"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1)  menu_info ;;
      2)  menu_brute ;;
      3)  menu_launch ;;
      4)  menu_comm ;;
      5)  menu_screen_camera ;;
      6)  menu_network ;;
      7)  menu_media ;;
      8)  menu_file ;;
      9)  menu_system ;;
      10) menu_chain ;;
      11) menu_logcat ;;
      12) menu_settings ;;
      0) return 0 ;;
      q|Q) session_summary; exit 0 ;;
      *) warn "Invalid choice"; sleep 1 ;;
    esac
  done
}
