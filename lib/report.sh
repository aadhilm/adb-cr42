#!/usr/bin/env bash
# lib/report.sh

report_init() {
  mkdir -p "$LOG_DIR"
  echo "device,pin,attempts,elapsed_s,status" > "$LOG_DIR/summary.csv"
  : > "$LOG_DIR/audit.log"
  : > "$LOG_DIR/unlocked.txt"
}

report_row() {
  printf '%s,%s,%s,%s,%s\n' "$1" "$2" "$3" "$4" "$5" >> "$LOG_DIR/summary.csv"
}

report_audit() {
  printf '%s user=%s dev=%s action=%s %s\n' \
    "$(date -Iseconds)" "${USER:-?}" "${1:-}" "${2:-}" "${3:-}" >> "$LOG_DIR/audit.log"
}

report_markdown() {
  local out="$LOG_DIR/report.md"
  {
    echo "# CR42 ADB Session Report"
    echo
    echo "Generated: $(date -Iseconds)"
    echo "Host: $(hostname)"
    echo
    echo "## Unlocked devices"
    echo '```'
    cat "$LOG_DIR/unlocked.txt" 2>/dev/null
    echo '```'
    echo
    echo "## Audit"
    echo '```'
    cat "$LOG_DIR/audit.log" 2>/dev/null
    echo '```'
  } > "$out"
}
