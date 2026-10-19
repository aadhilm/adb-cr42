#!/usr/bin/env bash
# lib/parallel.sh — per-device execution honoring EXEC_MODE

auto_set_mode() {
  if [ -z "${EXEC_MODE:-}" ]; then
    if [ "${#DEVICES[@]}" -le 1 ]; then
      EXEC_MODE="sequential"
    else
      EXEC_MODE="parallel"
    fi
    export EXEC_MODE
  fi
}

ensure_online() {
  local dev="$1"
  if ! adb -s "$dev" get-state >/dev/null 2>&1; then
    warn "Device $dev not reachable — skipping."
    return 1
  fi
  return 0
}

for_each_device() {
  local fn="$1"; shift
  auto_set_mode

  local d
  case "$EXEC_MODE" in
    parallel)
      local pids=()
      for d in "${DEVICES[@]}"; do
        ensure_online "$d" || continue
        ( "$fn" "$d" "$@" ) &
        pids+=($!)
      done
      local pid
      for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null
      done
      ;;
    *)
      for d in "${DEVICES[@]}"; do
        ensure_online "$d" || continue
        "$fn" "$d" "$@"
      done
      ;;
  esac
}

prompt_execution_mode() {
  if [ "${#DEVICES[@]}" -le 1 ]; then
    EXEC_MODE="sequential"
    export EXEC_MODE
    return
  fi
  echo
  echo "${c_bld}Execution mode [default-parallel]:${c_reset}"
  echo "  1) sequential  (one device at a time)"
  echo "  2) parallel    (all devices at once)"
  echo
  local c; read -rp "Choice [2]: " c
  case "$c" in
    1) EXEC_MODE="sequential" ;;
    *) EXEC_MODE="parallel" ;;
  esac
  export EXEC_MODE
  ok "Execution mode: $EXEC_MODE"
}
