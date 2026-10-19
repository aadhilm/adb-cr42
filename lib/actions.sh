#!/usr/bin/env bash
# lib/actions.sh — open, call, sms, screenshot, chain

open_web() {
  local dev="$1" url="${2:-}"
  if [ -z "$url" ]; then
    while :; do
      read -rp "URL (e.g. https://chatgpt.com): " url
      valid_url "$url" && break
      warn "Invalid URL"
    done
  fi
  log "Opening $url on $dev ..."
  adb -s "$dev" shell am start -a android.intent.action.VIEW -d "$url" >/dev/null 2>&1 \
    && ok "Opened on $dev" || err "Failed on $dev"
}

open_app_quiet() {
  local dev="$1" pkg="$2"
  log "Launching $pkg on $dev ..."
  local out
  out=$(adb -s "$dev" shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 2>&1)
  if echo "$out" | grep -qi "No activities found"; then
    local act
    act=$(adb -s "$dev" shell cmd package resolve-activity --brief "$pkg" 2>/dev/null \
          | tail -n1 | tr -d '\r')
    if [ -n "$act" ] && [ "$act" != "No activity found" ]; then
      adb -s "$dev" shell am start -n "$act" >/dev/null 2>&1 \
        && { ok "Launched on $dev"; return 0; }
    fi
    err "Could not launch on $dev"
    return 1
  fi
  ok "Launched on $dev"
}

call_person() {
  local dev="$1" num="${2:-}"
  [ -z "$num" ] && read -rp "Phone number: " num
  valid_phone "$num" || { err "Invalid number"; return 1; }
  log "Dialing $num on $dev ..."
  adb -s "$dev" shell am start -a android.intent.action.CALL -d "tel:$num" >/dev/null 2>&1 \
    && ok "Dialing on $dev" || err "Failed on $dev"
}

hang_up() {
  local dev="$1" delay="${2:-0}"
  [ "$delay" -gt 0 ] && { log "Hang-up in ${delay}s on $dev ..."; sleep "$delay"; }
  adb -s "$dev" shell input keyevent KEYCODE_ENDCALL >/dev/null 2>&1
  ok "Hung up on $dev"
}

send_sms() {
  local dev="$1" num="${2:-}" msg="${3:-}"
  [ -z "$num" ] && read -rp "Number: " num
  [ -z "$msg" ] && read -rp "Message: " msg
  log "Sending SMS to $num on $dev ..."
  adb -s "$dev" shell am start -a android.intent.action.SENDTO \
    -d "sms:$num" --es sms_body "$msg" --ez exit_on_sent true >/dev/null 2>&1 \
    && ok "SMS intent sent on $dev" || err "Failed on $dev"
}

take_screenshot() {
  local dev="$1" out="${2:-}"
  [ -z "$out" ] && out="$CR42_SHOTS/${dev//:/_}-$(date +%Y%m%d-%H%M%S).png"
  adb -s "$dev" exec-out screencap -p > "$out" 2>/dev/null
  [ -s "$out" ] && ok "Screenshot: $out" || err "Failed on $dev"
}

list_installed_apps() {
  local dev="$1" filter="${2:-}"
  local list
  list=$(adb -s "$dev" shell pm list packages -3 2>/dev/null | sed 's/package://' | tr -d '\r')
  [ -n "$filter" ] && echo "$list" | grep -i "$filter" || echo "$list"
}

check_locked_or_brute() {
  local dev="$1" focus
  focus=$(adb -s "$dev" shell dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus')
  if echo "$focus" | grep -qi 'keyguard\|lockscreen'; then
    warn "Device $dev appears LOCKED."
    read -rp "Brute force first? [y/n]: " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      local saved=("${DEVICES[@]}")
      DEVICES=("$dev")
      menu_brute
      DEVICES=("${saved[@]}")
    fi
  fi
}

# ---------- Launch / Open ----------
menu_launch() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Launch / Open (devices: ${#DEVICES[@]}) === [mode: ${EXEC_MODE:-sequential}]${c_reset}"
    echo "  1) Open app (list installed)"
    echo "  2) Open website"
    echo "  3) Open app + website (chain)"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1)
        local ref="${DEVICES[0]}"
        read -rp "Filter (empty = all): " filter
        mapfile -t apps < <(list_installed_apps "$ref" "$filter")
        [ "${#apps[@]}" -eq 0 ] && { warn "No apps found"; pause_enter; continue; }
        local i=1
        for a in "${apps[@]}"; do
          printf '  %d) %s\n' "$i" "$a"; i=$((i+1))
          [ "$i" -gt 30 ] && { echo "  ..."; break; }
        done
        read -rp "Pick number or type package: " pick
        local pkg
        if [[ "$pick" =~ ^[0-9]+$ ]] && (( pick>=1 && pick<=${#apps[@]} )); then
          pkg="${apps[$((pick-1))]}"
        else
          pkg="$pick"
        fi
        _pkg="$pkg"
        wrap_open_app() { open_app_quiet "$1" "$_pkg"; }
        for_each_device wrap_open_app
        pause_enter
        ;;
      2)
        read -rp "URL (e.g. https://chatgpt.com): " url
        valid_url "$url" || { err "Invalid URL"; pause_enter; continue; }
        _url="$url"
        wrap_open_web() { open_web "$1" "$_url"; }
        for_each_device wrap_open_web
        pause_enter
        ;;
      3)
        read -rp "Package: " pkg
        read -rp "URL: " url
        valid_url "$url" || { err "Invalid URL"; pause_enter; continue; }
        _pkg="$pkg"; _url="$url"
        wrap_app_web() {
          open_app_quiet "$1" "$_pkg" && sleep 3 && open_web "$1" "$_url"
        }
        for_each_device wrap_app_web
        pause_enter
        ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}

# ---------- Communication ----------
menu_comm() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Communication (devices: ${#DEVICES[@]}) === [mode: ${EXEC_MODE:-sequential}]${c_reset}"
    echo "  1) Call (dial / hang up)"
    echo "  2) SMS"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1)
        echo "  1) Dial"
        echo "  2) Hang up (with delay)"
        echo "  0) Back"
        local cc; read -rp "Choice: " cc
        case "$cc" in
          1)
            read -rp "Number: " num
            valid_phone "$num" || { err "Invalid"; pause_enter; continue; }
            _num="$num"
            wrap_call() { call_person "$1" "$_num"; }
            for_each_device wrap_call
            pause_enter
            ;;
          2)
            read -rp "Delay seconds (0=now): " d
            [[ "$d" =~ ^[0-9]+$ ]] || d=0
            _d="$d"
            wrap_hangup() { hang_up "$1" "$_d"; }
            for_each_device wrap_hangup
            pause_enter
            ;;
          0) continue ;;
        esac
        ;;
      2)
        read -rp "Number: " num
        read -rp "Message: " msg
        _num="$num"; _msg="$msg"
        wrap_sms() { send_sms "$1" "$_num" "$_msg"; }
        for_each_device wrap_sms
        pause_enter
        ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}

# ---------- Chain builder ----------
CHAIN_ACTIONS=()
CHAIN_ARGS=()

chain_add_action() {
  echo
  echo "  1) Brute force"
  echo "  2) Open app"
  echo "  3) Open website"
  echo "  4) Call"
  echo "  5) SMS"
  echo "  6) Screenshot"
  echo "  7) Wait <N>s"
  echo
  read -rp "Add action [1-7]: " a
  case "$a" in
    1) CHAIN_ACTIONS+=("brute");      CHAIN_ARGS+=("") ;;
    2) read -rp "Package: " p;        CHAIN_ACTIONS+=("app");   CHAIN_ARGS+=("$p") ;;
    3) read -rp "URL: " u;            CHAIN_ACTIONS+=("web");   CHAIN_ARGS+=("$u") ;;
    4) read -rp "Number: " n;         CHAIN_ACTIONS+=("call");  CHAIN_ARGS+=("$n") ;;
    5) read -rp "Number: " n; read -rp "Message: " m; CHAIN_ACTIONS+=("sms"); CHAIN_ARGS+=("$n|$m") ;;
    6) CHAIN_ACTIONS+=("screenshot"); CHAIN_ARGS+=("") ;;
    7) read -rp "Wait seconds: " w;   CHAIN_ACTIONS+=("wait");  CHAIN_ARGS+=("$w") ;;
    *) warn "Invalid" ;;
  esac
}

chain_show() {
  [ "${#CHAIN_ACTIONS[@]}" -eq 0 ] && { warn "Chain empty"; return; }
  echo "${c_bld}Chain:${c_reset}"
  local i
  for i in "${!CHAIN_ACTIONS[@]}"; do
    printf '  %d) %-10s %s\n' "$((i+1))" "${CHAIN_ACTIONS[$i]}" "${CHAIN_ARGS[$i]}"
  done
}

chain_run_one() {
  local dev="$1" i a arg
  for i in "${!CHAIN_ACTIONS[@]}"; do
    a="${CHAIN_ACTIONS[$i]}"
    arg="${CHAIN_ARGS[$i]}"
    case "$a" in
      brute)      brute_force_one_quiet "$dev" ;;
      app)        open_app_quiet "$dev" "$arg" ;;
      web)        open_web "$dev" "$arg" ;;
      call)       call_person "$dev" "$arg" ;;
      sms)        send_sms "$dev" "${arg%%|*}" "${arg##*|}" ;;
      screenshot) take_screenshot "$dev" ;;
      wait)       log "Wait ${arg}s on $dev ..."; sleep "$arg" ;;
    esac
  done
}

chain_save() {
  read -rp "Chain name: " name
  [ -z "$name" ] && return
  local f="$CR42_CHAINS/${name}.chain"; : > "$f"
  local i
  for i in "${!CHAIN_ACTIONS[@]}"; do
    printf '%s|%s\n' "${CHAIN_ACTIONS[$i]}" "${CHAIN_ARGS[$i]}" >> "$f"
  done
  ok "Saved to $f"
}

chain_load() {
  read -rp "Chain name: " name
  local f="$CR42_CHAINS/${name}.chain"
  [ -r "$f" ] || { err "No such chain"; return; }
  CHAIN_ACTIONS=(); CHAIN_ARGS=()
  while IFS='|' read -r a arg; do
    CHAIN_ACTIONS+=("$a"); CHAIN_ARGS+=("$arg")
  done < "$f"
  ok "Loaded ${#CHAIN_ACTIONS[@]} actions"
}

menu_chain() {
  while :; do
    clear_screen; banner
    echo "${c_bld}=== Chain Builder (devices: ${#DEVICES[@]}) === [mode: ${EXEC_MODE:-sequential}]${c_reset}"
    echo "  1) Add action"
    echo "  2) Show chain"
    echo "  3) Run chain"
    echo "  4) Save chain"
    echo "  5) Load chain"
    echo "  6) Clear"
    echo "  0) Back"
    echo
    local c; read -rp "Choice: " c
    case "$c" in
      1) chain_add_action ;;
      2) chain_show; pause_enter ;;
      3)
        chain_show
        [ "${#CHAIN_ACTIONS[@]}" -eq 0 ] && { pause_enter; continue; }
        read -rp "Run now? [Y/n]: " yn
        [[ "$yn" =~ ^[Nn]$ ]] && continue
        for_each_device chain_run_one
        pause_enter
        ;;
      4) chain_save; pause_enter ;;
      5) chain_load; pause_enter ;;
      6) CHAIN_ACTIONS=(); CHAIN_ARGS=(); ok "Cleared"; pause_enter ;;
      0) return 0 ;;
      *) warn "Invalid"; sleep 1 ;;
    esac
  done
}
