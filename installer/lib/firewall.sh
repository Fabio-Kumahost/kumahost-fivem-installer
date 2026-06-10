#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — firewall.sh
# Automatic firewall detection and rule management (ufw / firewalld / none).
# =============================================================================
[[ -n "${_KH_FIREWALL_SOURCED:-}" ]] && return 0
_KH_FIREWALL_SOURCED=1

# detect_firewall — echoes "ufw", "firewalld" or "none".
detect_firewall() {
  if has_command ufw && ufw status >/dev/null 2>&1; then
    echo "ufw"
  elif has_command firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    echo "firewalld"
  else
    echo "none"
  fi
}

# open_port PORT PROTO — open a single port on the active firewall.
open_port() {
  local port="$1" proto="${2:-tcp}" fw
  valid_port "$port" || { log_warn "Ungültiger Port übersprungen: $port"; return 0; }
  fw="$(detect_firewall)"
  case "$fw" in
    ufw)
      run ufw allow "${port}/${proto}"
      log_ok "ufw: Port ${port}/${proto} geöffnet" ;;
    firewalld)
      run firewall-cmd --permanent --add-port="${port}/${proto}"
      run firewall-cmd --reload
      log_ok "firewalld: Port ${port}/${proto} geöffnet" ;;
    none)
      log_detail "Keine aktive Firewall — Port ${port}/${proto} nicht angepasst." ;;
  esac
}

# firewall_check FIVEM_PORT TXADMIN_PORT — automatic firewall pre-flight.
# FiveM uses TCP+UDP on its game port; TxAdmin uses one TCP port.
firewall_check() {
  local game_port="${1:-30120}" txadmin_port="${2:-40120}" fw
  log_step "Automatische Firewall-Prüfung"
  fw="$(detect_firewall)"
  if [[ "$fw" == "none" ]]; then
    log_warn "Keine Firewall (ufw/firewalld) aktiv erkannt."
    log_detail "Stelle sicher, dass dein Hoster die Ports ${game_port} (TCP/UDP) und ${txadmin_port} (TCP) freigibt."
    return 0
  fi
  log_detail "Aktive Firewall: ${fw}"
  open_port "$game_port" tcp
  open_port "$game_port" udp
  open_port "$txadmin_port" tcp
  log_ok "Firewall-Regeln gesetzt"
}
