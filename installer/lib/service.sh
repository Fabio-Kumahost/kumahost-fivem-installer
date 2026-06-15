#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — service.sh
# systemd unit generation (screen-backed), lifecycle control, health checks.
#
# The server always runs inside a named screen session started by systemd:
#   systemd → screen -DmS fivem → run.sh (FXServer + txAdmin)
# Autostart + auto-restart come from systemd; `kumahost console` attaches to
# the live screen session. screen -L mirrors all output to the log file.
# =============================================================================
[[ -n "${_KH_SERVICE_SOURCED:-}" ]] && return 0
_KH_SERVICE_SOURCED=1

KH_SERVICE_NAME="${KH_SERVICE_NAME:-fivem}"
KH_SERVICE_UNIT="/etc/systemd/system/${KH_SERVICE_NAME}.service"
KH_TXADMIN_PORT="${KH_TXADMIN_PORT:-40120}"
KH_LOG_DIR="${KH_LOG_DIR:-/var/log/fivem}"
KH_SERVER_LOG="${KH_SERVER_LOG:-${KH_LOG_DIR}/server.log}"
KH_CLI_PATH="${KH_CLI_PATH:-/usr/local/bin/kumahost}"

# screen session name + a fixed socket dir so root can reliably attach.
KH_SCREEN_NAME="${KH_SCREEN_NAME:-fivem}"
KH_SCREEN_DIR="${KH_SCREEN_DIR:-${KH_FX_BASE}/.screen}"

# Location of the unit template relative to this library.
KH_TEMPLATE_DIR="${KH_TEMPLATE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../templates" && pwd)}"

# install_service — render the screen-backed unit and enable it.
install_service() {
  log_step "systemd-Service (screen) einrichten"
  has_command screen || die "screen ist nicht installiert — Dependency-Schritt prüfen."
  [[ -f "$KH_TEMPLATE_DIR/fivem.service" ]] \
    || die "Service-Vorlage fehlt: $KH_TEMPLATE_DIR/fivem.service"

  run mkdir -p "$KH_LOG_DIR"
  run chown "$KH_FX_USER:$KH_FX_USER" "$KH_LOG_DIR"
  run install -d -o "$KH_FX_USER" -g "$KH_FX_USER" -m 700 "$KH_SCREEN_DIR"

  # Flush the screen logfile every second so the txAdmin PIN shows up promptly
  # (screen's default flush interval is 10s). $HOME for the service is the base.
  printf 'logfile flush 1\n' >"${KH_FX_BASE}/.screenrc"
  run chown "$KH_FX_USER:$KH_FX_USER" "${KH_FX_BASE}/.screenrc"

  local screen_bin; screen_bin="$(command -v screen)"

  # Substitute placeholders into the live unit file.
  sed \
    -e "s#__KH_FX_USER__#${KH_FX_USER}#g" \
    -e "s#__KH_FX_DATA_DIR__#${KH_FX_DATA_DIR}#g" \
    -e "s#__KH_FX_ARTIFACT_DIR__#${KH_FX_ARTIFACT_DIR}#g" \
    -e "s#__KH_FX_BASE__#${KH_FX_BASE}#g" \
    -e "s#__KH_TXADMIN_PORT__#${KH_TXADMIN_PORT}#g" \
    -e "s#__KH_SCREEN_NAME__#${KH_SCREEN_NAME}#g" \
    -e "s#__KH_SCREEN_DIR__#${KH_SCREEN_DIR}#g" \
    -e "s#__KH_SCREEN_BIN__#${screen_bin}#g" \
    -e "s#__KH_SERVER_LOG__#${KH_SERVER_LOG}#g" \
    "$KH_TEMPLATE_DIR/fivem.service" >"$KH_SERVICE_UNIT" \
    || die "Konnte Service-Datei nicht schreiben."
  log_ok "Service-Datei erzeugt: ${KH_SERVICE_UNIT}"

  run systemctl daemon-reload
  run systemctl enable "$KH_SERVICE_NAME"
  log_ok "Service '${KH_SERVICE_NAME}' aktiviert (Autostart)"
  install_launcher
}

# install_launcher — install a `kumahost` command for later management
# (console, start, stop, update, …). It re-runs the installer from GitHub so
# it always uses the latest version.
install_launcher() {
  local owner="${KH_REPO_OWNER:-Fabio-Kumahost}"
  local name="${KH_REPO_NAME:-kumahost-fivem-installer}"
  local branch="${KH_REPO_BRANCH:-main}"
  cat >"$KH_CLI_PATH" <<LAUNCH
#!/usr/bin/env bash
# KumaHost FiveM Installer launcher (auto-generated — do not edit).
exec bash <(curl -sSL "https://raw.githubusercontent.com/${owner}/${name}/${branch}/install.sh") "\$@"
LAUNCH
  run chmod +x "$KH_CLI_PATH"
  log_ok "Befehl 'kumahost' installiert (${KH_CLI_PATH})"
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

# attach_console — attach to the live screen session as the service user.
# Detach again with Ctrl-A then D (do NOT use Ctrl-C — that stops the server).
attach_console() {
  has_command screen || die "screen ist nicht installiert."
  if ! systemctl is-active --quiet "$KH_SERVICE_NAME"; then
    log_warn "Service '${KH_SERVICE_NAME}' läuft nicht — starte ihn zuerst (kumahost start)."
    return 1
  fi
  log_info "Verbinde mit der Server-Konsole — Verlassen: Strg-A, dann D"
  runuser -u "$KH_FX_USER" -- env SCREENDIR="$KH_SCREEN_DIR" screen -r "$KH_SCREEN_NAME" \
    || log_warn "Keine laufende Session '${KH_SCREEN_NAME}' gefunden (evtl. startet der Server noch)."
}

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
  log_step "Health-Check (txAdmin Port ${KH_TXADMIN_PORT})"
  while (( elapsed < timeout )); do
    if has_command ss && ss -ltn 2>/dev/null | grep -q ":${KH_TXADMIN_PORT}\b"; then
      log_ok "txAdmin antwortet auf Port ${KH_TXADMIN_PORT}"
      return 0
    fi
    if ! systemctl is-active --quiet "$KH_SERVICE_NAME"; then
      log_error "Service wurde beendet — Diagnose folgt."
      diagnose_service
      return 1
    fi
    sleep 3; elapsed=$(( elapsed + 3 ))
  done
  log_warn "txAdmin-Port nach ${timeout}s nicht erreichbar."
  diagnose_service
  return 1
}

# diagnose_service — print the most useful failure context.
diagnose_service() {
  log_step "Fehlerdiagnose"
  log_detail "Status:"
  systemctl status "$KH_SERVICE_NAME" --no-pager -l 2>&1 | sed 's/^/    /' | tee -a "$KH_LOG_FILE"
  log_detail "Letzte Log-Zeilen (${KH_SERVER_LOG}):"
  tail -n 20 "$KH_SERVER_LOG" 2>/dev/null | sed 's/^/    /' || log_detail "(kein Log vorhanden)"
  log_detail "journalctl -u ${KH_SERVICE_NAME} -n 50 liefert weitere Details."
}

# start_and_verify — automatic service start followed by a health check.
start_and_verify() {
  start_service
  health_check 90 || log_warn "Server gestartet, aber Health-Check unvollständig — bitte Logs prüfen."
}
