#!/usr/bin/env bash
# lib/common.sh — colors, logging, banner, adb wrapper, pause

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\e[0m'; c_red=$'\e[31m'; c_grn=$'\e[32m'
  c_yel=$'\e[33m'; c_cyn=$'\e[36m'; c_bld=$'\e[1m'
else
  c_reset=""; c_red=""; c_grn=""; c_yel=""; c_cyn=""; c_bld=""
fi

log()  { printf '%s[*]%s %s\n' "$c_cyn" "$c_reset" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$c_grn" "$c_reset" "$*"; }
warn() { printf '%s[!]%s %s\n' "$c_yel" "$c_reset" "$*"; }
err()  { printf '%s[x]%s %s\n' "$c_red" "$c_reset" "$*" >&2; }

# DRY_RUN-aware adb wrapper
adb() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf '%s[dry]%s adb %s\n' "$c_yel" "$c_reset" "$*"
    return 0
  fi
  command adb "$@"
}

clear_screen() {
  if command -v clear >/dev/null 2>&1; then clear
  else printf '\033[H\033[2J'; fi
}

banner() {
  local art
  art=$(cat << 'BANNER_EOF'

                                          .   ,
                                        '. '.  \  \
                                        ._ '-.'. `\  \
                                          '-._; .'; `-.'
                                        `~-.; '.       '.
                                          '--,`           '.
                                            -='.          ;
                                  .--=~~=-,    -.;        ;
                                  .-=`;    `~,_.;        /
                                  `  ,-`'    .-;         |
                                    .-~`.    .;         ;
                                      .;.-   .-;         ,\
                                        `.'   ,=;     .-'  `~.-._
                                        .';   .';  .'      .'   '-.
                                          .\  ;  ;        ,.' _  a',
                                          .'~";-`   ;      ;"~` `'-=.)
                                        .' .'   . _;  ;',  ;
                                        '-.._`~`.'  \  ; ; :
                                            `~'    _'\_ \_
                                                  /=`^^=`""/`)-.
                                                  \ =  _ =     =\
                                                    `""` `~-. =   ;


   ▄▄▄       ██████╗ ██████╗     ▄▄▄█████▓▓█████   ██████ ▄▄▄█████▓    ▄████▄   ██▀███   ██▄▄▄▄
  ▒████▄    ██╔══██╗██╔══██╗    ▓  ██▒ ▓▒▓█   ▀ ▒██    ▒ ▓  ██▒ ▓▒   ▒██▀ ▀█  ▓██ ▒ ██▒▓██▓  ▓██▒
  ▒██  ▀█▄  ██║  ██║██████╔╝    ▒ ▓██░ ▒░▒███   ░ ▓██▄   ▒ ▓██░ ▒░   ▒▓█    ▄ ▓██ ░▄█ ▒▒▓█  ▄ ▓██▒
  ░██▄▄▄▄██ ██║  ██║██╔══██╗    ░ ▓██▓ ░ ▒▓█  ▄   ▒   ██▒░ ▓██▓ ░    ▒▓▓▄ ▄██▒▒██▀▀█▄  ░▒▓███▀▒
   ▓█   ▓██▒██████╔╝██████╔╝      ▒██▒ ░ ░▒████▒▒██████▒▒  ▒██▒ ░    ▒ ▓███▀ ░░██▓ ▒██▒░▒   ▒
   ▒▒   ▓▒█░╚═════╝ ╚═════╝       ▒ ░░   ░░ ▒░ ░▒ ▒▓▒ ▒ ░  ▒ ░░      ░ ░▒ ▒  ░░ ▒▓ ░▒▓░ ░   ░
    ░   ▒▒ ░                       ░       ░ ░  ░░ ░▒  ░ ░    ░         ░  ▒     ░▒ ░ ▒░ ░   ░
        ░  ░                     ░           ░   ░  ░  ░    ░         ░          ░░   ░        ░
                                             ░  ░      ░              ░ ░         ░

BANNER_EOF
)
  if command -v lolcat >/dev/null 2>&1; then
    printf '%s\n' "$art" | lolcat
  else
    printf '%s%s%s\n' "$c_cyn" "$art" "$c_reset"
  fi
  printf '\n%s%s%s\n\n' "$c_cyn" "                     Welcome to the CR42 ADB Toolkit!" "$c_reset"
}

pause_enter() {
  echo
  read -rp "Press Enter to continue..." _ || true
}
