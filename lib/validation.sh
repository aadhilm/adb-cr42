#!/usr/bin/env bash
# lib/validation.sh

valid_ip_port() {
  [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]{1,5}$ ]]
}
valid_url() {
  [[ "$1" =~ ^https?://[^[:space:]]+\.[^[:space:]]+ ]]
}
valid_pkg() {
  [[ "$1" =~ ^[A-Za-z0-9_.]+$ ]]
}
valid_phone() {
  [[ "$1" =~ ^[0-9+]{3,15}$ ]]
}
valid_port() {
  [[ "$1" =~ ^[0-9]{1,5}$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}
sanitize() {
  local s="$1"
  [[ "$s" =~ [\;\&\|\`\$\(\)\<\>\"\'\\] ]] && return 1
  printf '%s' "$s"
}
