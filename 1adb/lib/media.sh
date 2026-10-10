#!/usr/bin/env bash
# lib/media.sh — media control

media_play_pause() { adb -s "$1" shell input keyevent 85  >/dev/null 2>&1; ok "Play/Pause"; }
media_next()       { adb -s "$1" shell input keyevent 87  >/dev/null 2>&1; ok "Next"; }
media_prev()       { adb -s "$1" shell input keyevent 88  >/dev/null 2>&1; ok "Prev"; }
media_vol_up()     { adb -s "$1" shell input keyevent 24  >/dev/null 2>&1; ok "Vol+"; }
media_vol_down()   { adb -s "$1" shell input keyevent 25  >/dev/null 2>&1; ok "Vol-"; }
media_mute()       { adb -s "$1" shell input keyevent 164 >/dev/null 2>&1; ok "Mute"; }

play_audio() {
  local dev="$1" localfile="$2"
  [ -z "$localfile" ] && read -rp "Local audio file: " localfile
  [ -r "$localfile" ] || { err "Not found: $localfile"; return 1; }
  local base remote
  base=$(basename "$localfile")
  remote="/sdcard/Music/$base"
  adb -s "$dev" shell mkdir -p /sdcard/Music >/dev/null 2>&1
  adb -s "$dev" push "$localfile" "$remote" >/dev/null 2>&1 || { err "Push failed"; return 1; }
  adb -s "$dev" shell am start -a android.intent.action.VIEW \
    -d "file://$remote" -t "audio/*" >/dev/null 2>&1
  ok "Sent to player"
}

menu_media() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Media Control (devices: ${#DEVICES[@]}) === [mode: ${EXEC_MODE:-sequential}]${c_reset}"
    echo "  1) Play / Pause"
    echo "  2) Next"
    echo "  3) Previous"
    echo "  4) Volume up"
    echo "  5) Volume down"
    echo "  6) Mute"
    echo "  7) Push & play audio"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1) for_each_device media_play_pause; pause_enter ;;
      2) for_each_device media_next;       pause_enter ;;
      3) for_each_device media_prev;       pause_enter ;;
      4) for_each_device media_vol_up;     pause_enter ;;
      5) for_each_device media_vol_down;   pause_enter ;;
      6) for_each_device media_mute;       pause_enter ;;
      7) for_each_device play_audio;       pause_enter ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}
