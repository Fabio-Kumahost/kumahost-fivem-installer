#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — common.sh
# Shared helpers: colours, logging, prompts, command guards.
# Sourced by every other library; never executed on its own.
# =============================================================================

# Guard against double-sourcing.
[[ -n "${_KH_COMMON_SOURCED:-}" ]] && return 0
_KH_COMMON_SOURCED=1

# ---------------------------------------------------------------------------
# Terminal palette — mirrors the KumaHost brand (mauve/taupe on charcoal).
# Falls back to plain output when stdout is not a TTY or NO_COLOR is set.
# ---------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  KH_RESET=$'\e[0m'
  KH_BOLD=$'\e[1m'
  KH_DIM=$'\e[2m'
  KH_ACCENT=$'\e[38;2;168;129;148m'   # #a88194 mauve-rose
  KH_ACCENT2=$'\e[38;2;123;110;118m'  # #7b6e76 taupe
  KH_TEXT=$'\e[38;2;232;232;232m'     # #e8e8e8
  KH_OK=$'\e[38;2;0;182;122m'         # #00B67A success green
  KH_WARN=$'\e[38;2;230;180;80m'
  KH_ERR=$'\e[38;2;220;90;90m'
else
  KH_RESET="" KH_BOLD="" KH_DIM="" KH_ACCENT="" KH_ACCENT2=""
  KH_TEXT="" KH_OK="" KH_WARN="" KH_ERR=""
fi

# Log file is set by the entrypoint; default keeps standalone sourcing safe.
KH_LOG_FILE="${KH_LOG_FILE:-/var/log/kumahost-installer.log}"

# ---------------------------------------------------------------------------
# _kh_log LEVEL MESSAGE — timestamped append to the log file (best effort).
# ---------------------------------------------------------------------------
_kh_log() {
  local level="$1"; shift
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
  # Never abort the installer just because logging failed.
  printf '%s\n' "$line" >>"$KH_LOG_FILE" 2>/dev/null || true
}

log_info()    { printf '%s%s›%s %s\n'  "$KH_ACCENT" "$KH_BOLD" "$KH_RESET" "$*"; _kh_log INFO  "$*"; }
log_step()    { printf '%s%s▶ %s%s\n'  "$KH_ACCENT" "$KH_BOLD" "$*" "$KH_RESET"; _kh_log STEP  "$*"; }
log_ok()      { printf '%s✔%s %s\n'    "$KH_OK"     "$KH_RESET" "$*"; _kh_log OK    "$*"; }
log_warn()    { printf '%s⚠%s %s\n'    "$KH_WARN"   "$KH_RESET" "$*" >&2; _kh_log WARN  "$*"; }
log_error()   { printf '%s✖ %s%s\n'    "$KH_ERR"    "$*" "$KH_RESET" >&2; _kh_log ERROR "$*"; }
log_detail()  { printf '  %s%s%s\n'    "$KH_DIM"    "$*" "$KH_RESET"; _kh_log DETAIL "$*"; }

# die MESSAGE [EXIT_CODE] — log a fatal error and stop the installer.
die() {
  log_error "${1:-Unbekannter Fehler}"
  exit "${2:-1}"
}

# ---------------------------------------------------------------------------
# Banner — drawn with the brand gradient colours.
# ---------------------------------------------------------------------------
kh_banner() {
  printf '%s' "$KH_ACCENT$KH_BOLD"
  cat <<'BANNER'
   ╗  ╦ ╦ ╔╦╗ ╔═╗ ╦ ╦ ╔═╗ ╔═╗ ╔╦╗
   ║  ╠╩╗║ ║║║║╠═╣║ ║║ ║║ ║╚═╗ ║
   ╩  ╩ ╩ ╩ ╩ ╩ ╩ ╩ ╩ ╚═╝ ╚═╝ ╩
BANNER
  printf '%s' "$KH_RESET"
  printf '%s%s   KumaHost FiveM Installer%s %s· Premium Hosting%s\n\n' \
    "$KH_TEXT" "$KH_BOLD" "$KH_RESET" "$KH_ACCENT2" "$KH_RESET"
}

# ---------------------------------------------------------------------------
# Guards & small utilities.
# ---------------------------------------------------------------------------

# require_root — abort unless running as uid 0.
require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Bitte als root ausführen (z. B. via sudo)." 1
  fi
}

# has_command CMD — true if CMD is on PATH.
has_command() { command -v "$1" >/dev/null 2>&1; }

# run CMD... — run a command, mirror it to the log, fail loudly on error.
run() {
  _kh_log CMD "$*"
  if ! "$@" >>"$KH_LOG_FILE" 2>&1; then
    die "Befehl fehlgeschlagen: $* (Details in $KH_LOG_FILE)"
  fi
}

# confirm "Frage?" — yes/no prompt, defaults to No. Returns 0 on yes.
confirm() {
  local prompt="${1:-Fortfahren?}" answer
  read -r -p "$(printf '%s? %s[j/N]%s ' "$prompt" "$KH_ACCENT2" "$KH_RESET")" answer
  [[ "$answer" =~ ^([jJ]|[yY])$ ]]
}

# ask "Frage" "default" — read a value, returning the default on empty input.
ask() {
  local prompt="$1" default="${2:-}" answer
  read -r -p "$(printf '%s %s[%s]%s: ' "$prompt" "$KH_ACCENT2" "$default" "$KH_RESET")" answer
  printf '%s' "${answer:-$default}"
}

# valid_port N — true when N is a usable TCP/UDP port number.
valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }
