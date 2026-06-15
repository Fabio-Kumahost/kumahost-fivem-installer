#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — uninstall.sh (library)
# Remove the FiveM server, service and (optionally) data + service user.
# =============================================================================
[[ -n "${_KH_UNINSTALL_SOURCED:-}" ]] && return 0
_KH_UNINSTALL_SOURCED=1

# remove_server — interactive removal with an optional final data backup.
remove_server() {
  log_step "Server entfernen"
  log_warn "Dies entfernt den FiveM-Service und die Installation unter ${KH_FX_BASE}."
  confirm "Wirklich fortfahren" || { log_warn "Abgebrochen."; return 1; }

  if list_backups >/dev/null 2>&1 || [[ -d "$KH_FX_DATA_DIR" ]]; then
    if confirm "Vorher ein letztes Backup der server-data erstellen"; then
      create_backup >/dev/null || log_warn "Backup fehlgeschlagen — fahre fort."
    fi
  fi

  # Stop and disable the service if present.
  if [[ -f "$KH_SERVICE_UNIT" ]]; then
    systemctl stop "$KH_SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$KH_SERVICE_NAME" 2>/dev/null || true
    run rm -f "$KH_SERVICE_UNIT"
    run systemctl daemon-reload
    log_ok "Service entfernt"
  fi

  local keep_backups=1
  if confirm "Auch Backups unter ${KH_BACKUP_DIR} löschen"; then keep_backups=0; fi

  if (( keep_backups )) && [[ -d "$KH_BACKUP_DIR" ]]; then
    local saved; saved="$(mktemp -d)/kumahost-backups"
    run mv "$KH_BACKUP_DIR" "$saved"
    run rm -rf "$KH_FX_BASE"
    run mkdir -p "$KH_BACKUP_DIR"
    run mv "$saved"/* "$KH_BACKUP_DIR"/ 2>/dev/null || true
    log_ok "Installation entfernt — Backups erhalten unter ${KH_BACKUP_DIR}"
  else
    run rm -rf "$KH_FX_BASE"
    log_ok "Installation und Backups entfernt"
  fi

  if confirm "Service-Benutzer '${KH_FX_USER}' ebenfalls löschen"; then
    userdel "$KH_FX_USER" 2>/dev/null && log_ok "Benutzer ${KH_FX_USER} gelöscht" \
      || log_warn "Benutzer konnte nicht gelöscht werden (evtl. nicht vorhanden)."
  fi

  run rm -rf /var/log/fivem
  rm -f "${KH_CLI_PATH:-/usr/local/bin/kumahost}" 2>/dev/null || true
  log_ok "Deinstallation abgeschlossen"
}
