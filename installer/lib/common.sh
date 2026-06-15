#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — common.sh
# Shared helpers: palette, logging, UI primitives, prompts, command guards.
# Sourced by every other library; never executed on its own.
# =============================================================================

# Guard against double-sourcing.
[[ -n "${_KH_COMMON_SOURCED:-}" ]] && return 0
_KH_COMMON_SOURCED=1

# ---------------------------------------------------------------------------
# Terminal palette — KumaHost brand (mauve/teal on charcoal).
# Falls back to plain output when stdout is not a TTY or NO_COLOR is set.
# ---------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  KH_RESET=$'\e[0m'
  KH_BOLD=$'\e[1m'
  KH_DIM=$'\e[2m'
  KH_ACCENT=$'\e[38;2;198;150;170m'   # #c696aa mauve-rose (primary)
  KH_ACCENT2=$'\e[38;2;120;108;116m'  # #786c74 taupe (muted)
  KH_ACCENT3=$'\e[38;2;94;214;199m'   # #5ed6c7 teal (highlight)
  KH_TEXT=$'\e[38;2;235;235;235m'     # #ebebeb near-white
  KH_OK=$'\e[38;2;0;200;130m'         # success green
  KH_WARN=$'\e[38;2;235;185;80m'      # amber
  KH_ERR=$'\e[38;2;225;95;95m'        # red
else
  KH_RESET="" KH_BOLD="" KH_DIM="" KH_ACCENT="" KH_ACCENT2="" KH_ACCENT3=""
  KH_TEXT="" KH_OK="" KH_WARN="" KH_ERR=""
fi

# Visual width of panels/rules. Adjust once, everything follows.
KH_UI_WIDTH="${KH_UI_WIDTH:-54}"

# Log file is set by the entrypoint; default keeps standalone sourcing safe.
KH_LOG_FILE="${KH_LOG_FILE:-/var/log/kumahost-installer.log}"

# ---------------------------------------------------------------------------
# _kh_log LEVEL MESSAGE — timestamped append to the log file (best effort).
# ---------------------------------------------------------------------------
_kh_log() {
  local level="$1"; shift
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
  printf '%s\n' "$line" >>"$KH_LOG_FILE" 2>/dev/null || true
}

# _kh_repeat STR N — repeat STR N times (multibyte-safe, no external tools).
_kh_repeat() {
  local s="$1" n="$2" out=''
  while (( n-- > 0 )); do out+="$s"; done
  printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# Logging primitives.
# ---------------------------------------------------------------------------
log_info()    { printf '%s%s›%s %s\n'   "$KH_ACCENT3" "$KH_BOLD" "$KH_RESET" "$*"; _kh_log INFO   "$*"; }
log_step()    { printf '\n%s%s▸%s %s%s%s\n' "$KH_ACCENT" "$KH_BOLD" "$KH_RESET" "$KH_BOLD" "$*" "$KH_RESET"; _kh_log STEP "$*"; }
log_ok()      { printf '  %s✔%s %s\n'   "$KH_OK"   "$KH_RESET" "$*"; _kh_log OK     "$*"; }
log_warn()    { printf '  %s▲%s %s\n'   "$KH_WARN" "$KH_RESET" "$*" >&2; _kh_log WARN  "$*"; }
log_error()   { printf '  %s✖ %s%s\n'   "$KH_ERR"  "$*" "$KH_RESET" >&2; _kh_log ERROR "$*"; }
log_detail()  { printf '    %s%s%s\n'   "$KH_DIM"  "$*" "$KH_RESET"; _kh_log DETAIL "$*"; }

# die MESSAGE [EXIT_CODE] — log a fatal error and stop the installer.
die() {
  log_error "${1:-Unbekannter Fehler}"
  exit "${2:-1}"
}

# ---------------------------------------------------------------------------
# UI primitives — rules, panels, key/value rows, menu items.
# Panel content is kept plain (no inline colour) so padding stays aligned.
# ---------------------------------------------------------------------------
kh_rule() {
  printf '  %s%s%s\n' "$KH_ACCENT2" "$(_kh_repeat '─' "$KH_UI_WIDTH")" "$KH_RESET"
}

kh_panel_top() {
  printf '  %s╭%s╮%s\n' "$KH_ACCENT" "$(_kh_repeat '─' "$KH_UI_WIDTH")" "$KH_RESET"
}
kh_panel_bottom() {
  printf '  %s╰%s╯%s\n' "$KH_ACCENT" "$(_kh_repeat '─' "$KH_UI_WIDTH")" "$KH_RESET"
}
kh_panel_divider() {
  printf '  %s├%s┤%s\n' "$KH_ACCENT" "$(_kh_repeat '─' "$KH_UI_WIDTH")" "$KH_RESET"
}
# kh_panel_line TEXT — one boxed row (plain text, left-aligned, padded).
kh_panel_line() {
  local text="$1" inner=$(( KH_UI_WIDTH - 2 ))
  printf '  %s│%s %-*s %s│%s\n' \
    "$KH_ACCENT" "$KH_RESET" "$inner" "$text" "$KH_ACCENT" "$KH_RESET"
}
# kh_panel_kv KEY VALUE — boxed key/value row with aligned columns.
kh_panel_kv() {
  local key="$1" val="$2" inner=$(( KH_UI_WIDTH - 2 ))
  printf '  %s│%s %s%-12s%s %-*s %s│%s\n' \
    "$KH_ACCENT" "$KH_RESET" "$KH_ACCENT3" "$key" "$KH_RESET" \
    "$(( inner - 13 ))" "$val" "$KH_ACCENT" "$KH_RESET"
}

# kh_menu_item KEY LABEL [HINT] — a styled menu entry.
kh_menu_item() {
  printf '   %s%s[%s]%s %s%-30s%s %s%s%s\n' \
    "$KH_BOLD" "$KH_ACCENT" "$1" "$KH_RESET" \
    "$KH_TEXT" "$2" "$KH_RESET" "$KH_DIM" "${3:-}" "$KH_RESET"
}
# kh_menu_group LABEL — a small group heading inside the menu.
kh_menu_group() {
  printf '\n  %s%s%s\n' "$KH_ACCENT2" "$1" "$KH_RESET"
}

# ---------------------------------------------------------------------------
# Banner — clean boxed wordmark, renders consistently on any terminal.
# ---------------------------------------------------------------------------
kh_banner() {
  clear 2>/dev/null || true
  printf '\n'
  kh_panel_top
  kh_panel_line ""
  kh_panel_line "K U M A H O S T   ·   FiveM Installer"
  kh_panel_line "Premium Game Server Hosting"
  kh_panel_line ""
  kh_panel_bottom
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
  read -r -p "$(printf '  %s%s?%s %s %s[j/N]%s ' "$KH_ACCENT3" "$KH_BOLD" "$KH_RESET" "$prompt" "$KH_ACCENT2" "$KH_RESET")" answer
  [[ "$answer" =~ ^([jJ]|[yY])$ ]]
}

# ask "Frage" "default" — read a value, returning the default on empty input.
ask() {
  local prompt="$1" default="${2:-}" answer
  read -r -p "$(printf '  %s▸%s %s %s[%s]%s: ' "$KH_ACCENT" "$KH_RESET" "$prompt" "$KH_ACCENT2" "$default" "$KH_RESET")" answer
  printf '%s' "${answer:-$default}"
}

# valid_port N — true when N is a usable TCP/UDP port number.
valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }
