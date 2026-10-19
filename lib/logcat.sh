#!/usr/bin/env bash
# lib/logcat.sh

menu_logcat() {
  local dev="${DEVICES[0]}"
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Live Log ($dev) ===${c_reset}"
    echo "  1) Live log"
    echo "  2) App log"
    echo "  3) Keyword (one or more)"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1)
        log "Live logcat on $dev (Ctrl-C to stop)"
        adb -s "$dev" logcat -v time
        ;;
      2)
        read -rp "App tag/keyword: " kw
        [ -z "$kw" ] && continue
        adb -s "$dev" logcat -v time | grep --line-buffered -Ei "(^|[^a-z])${kw}([^a-z]|$)"
        ;;
      3)
        read -rp "Keywords (comma or space): " kws
        [ -z "$kws" ] && continue
        kws="${kws//,/ }"
        local pat="" k
        for k in $kws; do
          [ -z "$k" ] && continue
          [ -z "$pat" ] && pat="$k" || pat="$pat|$k"
        done
        adb -s "$dev" logcat -v time | grep --line-buffered -Ei "($pat)"
        ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
    pause_enter
  done
}
