#!/usr/bin/env bash
# lib/screen.sh — screen + camera + mic

screen_record() {
  local dev="$1"
  read -rp "Duration seconds [30]: " dur
  [ -z "$dur" ] && dur=30
  local remote="/sdcard/cr42-sr-$(date +%s).mp4"
  local out="$CR42_SHOTS/${dev//:/_}-screen-$(date +%Y%m%d-%H%M%S).mp4"
  log "Recording screen ${dur}s on $dev ..."
  adb -s "$dev" shell screenrecord --time-limit "$dur" "$remote" &
  local pid=$!
  wait "$pid" 2>/dev/null
  sleep 1
  adb -s "$dev" pull "$remote" "$out" >/dev/null 2>&1
  adb -s "$dev" shell rm "$remote" >/dev/null 2>&1
  [ -s "$out" ] && ok "Saved: $out" || err "Failed on $dev"
}

screen_scrcpy() {
  local dev="$1"
  command -v scrcpy >/dev/null 2>&1 || { err "scrcpy not installed"; return 1; }
  log "Launching scrcpy on $dev ..."
  scrcpy -s "$dev"
}

take_photo() {
  local dev="$1" facing="${2:-rear}"
  log "Opening $facing camera on $dev ..."
  local cf=0
  [ "$facing" = "front" ] && cf=1
  adb -s "$dev" shell am start -a android.media.action.STILL_IMAGE_CAMERA \
    --ei android.intent.extras.CAMERA_FACING "$cf" >/dev/null 2>&1
  sleep 2
  adb -s "$dev" shell input keyevent KEYCODE_CAMERA >/dev/null 2>&1
  sleep 2
  ok "Photo captured on $dev"
}

camera_record_video() {
  local dev="$1" facing="${2:-rear}"
  read -rp "Duration seconds [15]: " dur
  [ -z "$dur" ] && dur=15
  log "Opening $facing camera video on $dev ..."
  local cf=0
  [ "$facing" = "front" ] && cf=1
  adb -s "$dev" shell am start -a android.media.action.VIDEO_CAPTURE \
    --ei android.intent.extras.CAMERA_FACING "$cf" >/dev/null 2>&1
  sleep 3
  adb -s "$dev" shell input keyevent KEYCODE_CAMERA >/dev/null 2>&1
  log "Recording ${dur}s ..."
  sleep "$dur"
  adb -s "$dev" shell input keyevent KEYCODE_CAMERA >/dev/null 2>&1
  sleep 2
  ok "Video sent to device camera app"
}

record_audio() {
  local dev="$1"
  read -rp "Duration seconds [10]: " dur
  [ -z "$dur" ] && dur=10
  log "Recording audio ${dur}s on $dev ..."
  adb -s "$dev" shell am start -a android.provider.MediaStore.RECORD_SOUND >/dev/null 2>&1
  sleep 2
  adb -s "$dev" shell input keyevent KEYCODE_MEDIA_RECORD >/dev/null 2>&1
  sleep "$dur"
  adb -s "$dev" shell input keyevent KEYCODE_MEDIA_STOP >/dev/null 2>&1
  sleep 2
  local newest
  newest=$(adb -s "$dev" shell "ls -t /sdcard/Sounds/*.m4a /sdcard/Music/*.m4a /sdcard/Recordings/* 2>/dev/null | head -1" | tr -d '\r')
  if [ -n "$newest" ]; then
    local out="$CR42_SHOTS/${dev//:/_}-audio-$(date +%Y%m%d-%H%M%S).m4a"
    adb -s "$dev" pull "$newest" "$out" >/dev/null 2>&1
    [ -s "$out" ] && ok "Saved: $out" || warn "Recorded on device but pull failed"
  else
    warn "Audio recorded on device — check Recorder app."
  fi
}

menu_screen_camera() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Device Screen & Camera / Mic (devices: ${#DEVICES[@]}) === [mode: ${EXEC_MODE:-sequential}]${c_reset}"
    echo "  1) Take photo (rear / front)"
    echo "  2) Record screen (mp4)"
    echo "  3) Live mirror (scrcpy)"
    echo "  4) Record video (camera, rear / front)"
    echo "  5) Mic: record audio"
    echo "  6) Take screenshot"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1)
        echo "  1) rear"
        echo "  2) front"
        local f; read -rp "Facing [1]: " f
        local facing="rear"; [ "$f" = "2" ] && facing="front"
        _facing="$facing"
        wrap_photo() { take_photo "$1" "$_facing"; }
        for_each_device wrap_photo
        pause_enter
        ;;
      2) for_each_device screen_record; pause_enter ;;
      3) screen_scrcpy "${DEVICES[0]}"; pause_enter ;;
      4)
        echo "  1) rear"
        echo "  2) front"
        local f; read -rp "Facing [1]: " f
        local facing="rear"; [ "$f" = "2" ] && facing="front"
        _facing="$facing"
        wrap_vid() { camera_record_video "$1" "$_facing"; }
        for_each_device wrap_vid
        pause_enter
        ;;
      5) for_each_device record_audio; pause_enter ;;
      6) for_each_device take_screenshot; pause_enter ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}
