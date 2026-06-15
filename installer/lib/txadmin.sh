#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — txadmin.sh
# TxAdmin ships inside the FXServer artifact and manages the server itself
# (resources, server.cfg, license key) via its web panel. This module only
# prepares an empty, correctly-owned server-data directory and surfaces the
# first-run setup PIN — everything else is done in the txAdmin web UI.
# =============================================================================
[[ -n "${_KH_TXADMIN_SOURCED:-}" ]] && return 0
_KH_TXADMIN_SOURCED=1

KH_FX_GAME_PORT="${KH_FX_GAME_PORT:-30120}"

# prepare_server_data — create the (initially empty) data dir txAdmin deploys
# into. We deliberately do NOT clone cfx-server-data or write a server.cfg:
# txAdmin's first-run recipe handles all of that from the web panel.
prepare_server_data() {
  log_step "Server-Datenverzeichnis vorbereiten"
  run mkdir -p "$KH_FX_DATA_DIR"
  run chown -R "$KH_FX_USER:$KH_FX_USER" "$KH_FX_DATA_DIR"
  log_ok "Bereit: ${KH_FX_DATA_DIR}"
  log_detail "Ressourcen, server.cfg und Lizenz-Key richtest du im txAdmin-Webpanel ein."
}

# setup_txadmin — full TxAdmin preparation step (data dir only).
setup_txadmin() {
  prepare_server_data
}

# _kh_find_pin LOGFILE — extract the txAdmin first-run PIN from a log file.
# txAdmin prints the PIN as a standalone boxed line *after* an announcement
# line that mentions "PIN", e.g.:
#     [txAdmin] Use the PIN below to register the master account:
#                          ║   1234   ║
# So we scan the 8 lines following any "pin" mention and take the first
# stand-alone 4-digit number. \b[0-9]{4}\b ignores 5-digit ports (40120/30120).
# ANSI colour codes are stripped first. Returns non-zero if no PIN found.
_kh_find_pin() {
  local log="$1"
  [[ -r "$log" ]] || return 1
  sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$log" 2>/dev/null \
    | grep -aiA8 'pin' 2>/dev/null \
    | grep -aoE '\b[0-9]{4}\b' 2>/dev/null \
    | head -1
}

# show_txadmin_hint — print first-run TxAdmin access details and the setup PIN.
show_txadmin_hint() {
  local ip log="/var/log/fivem/server.log" pin elapsed=0
  ip="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || echo 'SERVER-IP')"

  # The service writes FXServer/TxAdmin output to the log file via screen -L,
  # NOT the journal, so the first-run PIN never appears in `journalctl`.
  # Poll up to 60s (txAdmin needs a moment after the port opens to print it).
  while (( elapsed < 60 )); do
    pin="$(_kh_find_pin "$log" || true)"
    [[ -n "$pin" ]] && break
    sleep 3; elapsed=$(( elapsed + 3 ))
  done

  kh_panel_top
  kh_panel_line "txAdmin — Ersteinrichtung"
  kh_panel_divider
  kh_panel_kv "Webpanel" "http://${ip}:${KH_TXADMIN_PORT}"
  if [[ -n "$pin" ]]; then
    kh_panel_kv "Setup-PIN" "$pin"
  else
    kh_panel_kv "Setup-PIN" "siehe Log (s. u.)"
  fi
  kh_panel_kv "Konsole" "kumahost console"
  kh_panel_bottom
  if [[ -z "$pin" ]]; then
    log_detail "PIN noch nicht im Log — anzeigen mit: grep -i pin ${log}"
  fi
}
