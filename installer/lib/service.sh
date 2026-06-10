#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — service.sh
# systemd unit generation, lifecycle control and health checks.
# =============================================================================
[[ -n "${_KH_SERVICE_SOURCED:-}" ]] && return 0
_KH_SERVICE_SOURCED=1

KH_SERVICE_NAME="${KH_SERVICE_NAME:-fivem}"
KH_SERVICE_UNIT="/etc/systemd/system/${KH_SERVICE_NAME}.service"
KH_TXADMIN_PORT="${KH_TXADMIN_PORT:-40120}"
# Location of the unit template relative to this library.
KH_TEMPLATE_DIR="${KH_TEMPLATE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../templates" && pwd)}"

# install_service — render the template and enable the unit.
install_service() {
  log_step "Automatische TxAdmin-Installation & systemd-Service"
  [[ -f "$KH_TEMPLATE_DIR/fivem.service" ]] \
    || die "Service-Vorlage fehlt: $KH_TEMPLATE_DIR/fivem.service"

  run mkdir -p /var/log/fivem
  run chown "$KH_FX_USER:$KH_FX_USER" /var/log/fivem

  # Substitute placeholders into the live unit file.
  sed \
    -e "s#__KH_FX_USER__#${KH_FX_USER}#g" \
    -e "s#__KH_FX_DATA_DIR__#${KH_FX_DATA_DIR}#g" \
    -e "s#__KH_FX_ARTIFACT_DIR__#${KH_FX_ARTIFACT_DIR}#g" \
    -e "s#__KH_FX_BASE__#${KH_FX_BASE}#g" \
    -e "s#__KH_TXADMIN_PORT__#${KH_TXADMIN_PORT}#g" \
    "$KH_TEMPLATE_DIR/fivem.service" >"$KH_SERVICE_UNIT" \
    || die "Konnte Service-Datei nicht schreiben."
  log_ok "Service-Datei erzeugt: ${KH_SERVICE_UNIT}"

  run systemctl daemon-reload
  run systemctl enable "$KH_SERVICE_NAME"
  log_ok "Service '${KH_SERVICE_NAME}' aktiviert (Autostart)"
}

# service_action ACTION — thin wrapper around systemctl with logging.
service_action() {
  local action="$1"
  run systemctl "$action" "$KH_SERVICE_NAME"
  log_ok "systemctl ${action} ${KH_SERVICE_NAME}"
}

start_service()   { service_action start; }
stop_service()    { service_action stop; }
restart_service() { service_action restart; }

# service_status — human-readable status line (does not abort on inactive).
service_status() {
  if systemctl is-active --quiet "$KH_SERVICE_NAME"; then
    log_ok "Server läuft (${KH_SERVICE_NAME} aktiv)"
    return 0
  fi
  log_warn "Server ist nicht aktiv (${KH_SERVICE_NAME})"
  return 1
}

# health_check [TIMEOUT] — start the service and verify the TxAdmin port opens.
health_check() {
  local timeout="${1:-60}" elapsed=0
  log_step "Health-Check (TxAdmin Port ${KH_TXADMIN_PORT})"
  while (( elapsed < timeout )); do
    if has_command ss && ss -ltn 2>/dev/null | grep -q ":${KH_TXADMIN_PORT}\b"; then
      log_ok "TxAdmin antwortet auf Port ${KH_TXADMIN_PORT}"
      return 0
    fi
    if ! systemctl is-active --quiet "$KH_SERVICE_NAME"; then
      log_error "Service wurde beendet — Diagnose folgt."
      diagnose_service
      return 1
    fi
    sleep 3; elapsed=$(( elapsed + 3 ))
  done
  log_warn "TxAdmin-Port nach ${timeout}s nicht erreichbar."
  diagnose_service
  return 1
}

# diagnose_service — print the most useful failure context.
diagnose_service() {
  log_step "Fehlerdiagnose"
  log_detail "Status:"
  systemctl status "$KH_SERVICE_NAME" --no-pager -l 2>&1 | sed 's/^/    /' | tee -a "$KH_LOG_FILE"
  log_detail "Letzte Log-Zeilen (/var/log/fivem/server.log):"
  tail -n 20 /var/log/fivem/server.log 2>/dev/null | sed 's/^/    /' || log_detail "(kein Log vorhanden)"
  log_detail "journalctl -u ${KH_SERVICE_NAME} -n 50 liefert weitere Details."
}

# start_and_verify — automatic service start followed by a health check.
start_and_verify() {
  start_service
  health_check 90 || log_warn "Server gestartet, aber Health-Check unvollständig — bitte Logs prüfen."
}
