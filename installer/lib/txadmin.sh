#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — txadmin.sh
# TxAdmin is shipped inside the FXServer artifact; this module prepares the
# server-data directory and a starter server.cfg, then surfaces the setup PIN.
# =============================================================================
[[ -n "${_KH_TXADMIN_SOURCED:-}" ]] && return 0
_KH_TXADMIN_SOURCED=1

KH_SERVER_DATA_REPO="https://github.com/citizenfx/cfx-server-data.git"
KH_FX_GAME_PORT="${KH_FX_GAME_PORT:-30120}"

# prepare_server_data — populate server-data with the official resource base.
prepare_server_data() {
  log_step "Server-Daten vorbereiten"
  if [[ -d "$KH_FX_DATA_DIR/resources" ]]; then
    log_detail "server-data bereits vorhanden — überspringe Klonen."
  else
    run git clone --depth 1 "$KH_SERVER_DATA_REPO" "$KH_FX_DATA_DIR"
    log_ok "cfx-server-data nach ${KH_FX_DATA_DIR} geklont"
  fi
}

# generate_server_cfg — write a sane starter config if none exists.
generate_server_cfg() {
  local cfg="$KH_FX_DATA_DIR/server.cfg"
  if [[ -f "$cfg" ]]; then
    log_detail "server.cfg existiert bereits — bleibt unverändert."
    return 0
  fi
  local license_key
  license_key="${KH_LICENSE_KEY:-$(ask 'FiveM License-Key (cfx.re/console, leer = später) ' '')}"
  cat >"$cfg" <<CFG
## KumaHost FiveM Installer — starter server.cfg
## TxAdmin verwaltet die meisten Einstellungen über das Web-Panel.

endpoint_add_tcp "0.0.0.0:${KH_FX_GAME_PORT}"
endpoint_add_udp "0.0.0.0:${KH_FX_GAME_PORT}"

# Standard-Ressourcen
ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap

set sv_hostname "KumaHost FiveM Server"
sets sv_projectName "KumaHost"
sets sv_projectDesc "Powered by KumaHost — Premium Hosting"
set sv_maxclients 48
set onesync on

sv_licenseKey ${license_key:-changeme}
CFG
  run chown "$KH_FX_USER:$KH_FX_USER" "$cfg"
  log_ok "Starter-server.cfg erzeugt: ${cfg}"
  [[ -z "$license_key" ]] && log_warn "Kein License-Key gesetzt — vor dem Live-Betrieb in server.cfg eintragen (cfx.re/console)."
}

# show_txadmin_hint — print first-run TxAdmin access details.
show_txadmin_hint() {
  local ip
  ip="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || echo 'SERVER-IP')"
  printf '\n%s%s── TxAdmin Setup ────────────────────────────────%s\n' \
    "$KH_ACCENT" "$KH_BOLD" "$KH_RESET"
  log_detail "Web-Oberfläche:  http://${ip}:${KH_TXADMIN_PORT}"
  log_detail "Beim ersten Start zeigt das Server-Log eine PIN für die Einrichtung an:"
  log_detail "  journalctl -u ${KH_SERVICE_NAME} -f   (oder tail -f /var/log/fivem/server.log)"
  printf '%s─────────────────────────────────────────────────%s\n\n' "$KH_ACCENT" "$KH_RESET"
}

# setup_txadmin — full TxAdmin preparation step.
setup_txadmin() {
  prepare_server_data
  generate_server_cfg
  run chown -R "$KH_FX_USER:$KH_FX_USER" "$KH_FX_DATA_DIR"
}
