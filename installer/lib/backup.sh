#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — backup.sh
# Create, list and restore compressed backups of server-data (+ MariaDB dump).
# =============================================================================
[[ -n "${_KH_BACKUP_SOURCED:-}" ]] && return 0
_KH_BACKUP_SOURCED=1

KH_BACKUP_DIR="${KH_BACKUP_DIR:-${KH_FX_BASE}/backups}"

# create_backup — archive server-data and, if present, dump the database.
create_backup() {
  log_step "Backup erstellen"
  [[ -d "$KH_FX_DATA_DIR" ]] || die "Keine server-data gefunden unter ${KH_FX_DATA_DIR}."
  run mkdir -p "$KH_BACKUP_DIR"

  local stamp archive tmp
  stamp="$(date '+%Y%m%d-%H%M%S')"
  archive="${KH_BACKUP_DIR}/fivem-backup-${stamp}.tar.gz"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN

  # Optional database dump alongside the file data.
  if [[ -r "$KH_DB_CRED_FILE" ]] && has_command mysqldump; then
    # shellcheck disable=SC1090
    . "$KH_DB_CRED_FILE"
    log_detail "Erzeuge Datenbank-Dump (${DB_NAME})"
    mysqldump --single-transaction -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
      >"$tmp/database.sql" 2>>"$KH_LOG_FILE" \
      || log_warn "Datenbank-Dump fehlgeschlagen — fahre mit Dateien fort."
  fi

  log_detail "Komprimiere server-data …"
  # Store server-data relative to its parent for clean restores.
  if ! tar -czf "$archive" \
        -C "$(dirname "$KH_FX_DATA_DIR")" "$(basename "$KH_FX_DATA_DIR")" \
        ${DB_NAME:+-C "$tmp" database.sql} >>"$KH_LOG_FILE" 2>&1; then
    die "Backup-Erstellung fehlgeschlagen."
  fi
  log_ok "Backup erstellt: ${archive} ($(du -h "$archive" | cut -f1))"
  printf '%s\n' "$archive"
}

# list_backups — echo available backups newest-first; returns 1 if none.
list_backups() {
  [[ -d "$KH_BACKUP_DIR" ]] || { log_warn "Kein Backup-Verzeichnis."; return 1; }
  local found=0 i=1 f
  while IFS= read -r f; do
    found=1
    printf '  %s[%d]%s %s  %s%s%s\n' "$KH_ACCENT" "$i" "$KH_RESET" \
      "$(basename "$f")" "$KH_DIM" "$(du -h "$f" | cut -f1)" "$KH_RESET"
    i=$(( i + 1 ))
  done < <(ls -1t "$KH_BACKUP_DIR"/fivem-backup-*.tar.gz 2>/dev/null)
  (( found )) || { log_warn "Keine Backups vorhanden."; return 1; }
}

# restore_backup [ARCHIVE] — restore a chosen (or given) archive.
restore_backup() {
  log_step "Backup wiederherstellen"
  local archive="${1:-}"
  if [[ -z "$archive" ]]; then
    list_backups || return 1
    local idx file
    idx="$(ask 'Backup-Nummer wählen' '1')"
    file="$(ls -1t "$KH_BACKUP_DIR"/fivem-backup-*.tar.gz 2>/dev/null | sed -n "${idx}p")"
    [[ -n "$file" ]] || die "Ungültige Auswahl."
    archive="$file"
  fi
  [[ -f "$archive" ]] || die "Backup nicht gefunden: $archive"

  confirm "Aktuelle server-data wird überschrieben — fortfahren" || { log_warn "Abgebrochen."; return 1; }

  # Stop the server during restore if it is running.
  local was_running=0
  if systemctl is-active --quiet "$KH_SERVICE_NAME" 2>/dev/null; then
    was_running=1; stop_service
  fi

  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  run tar -xzf "$archive" -C "$tmp"

  if [[ -d "$tmp/$(basename "$KH_FX_DATA_DIR")" ]]; then
    run rm -rf "$KH_FX_DATA_DIR"
    run mv "$tmp/$(basename "$KH_FX_DATA_DIR")" "$KH_FX_DATA_DIR"
    run chown -R "$KH_FX_USER:$KH_FX_USER" "$KH_FX_DATA_DIR"
    log_ok "server-data wiederhergestellt"
  fi

  if [[ -f "$tmp/database.sql" && -r "$KH_DB_CRED_FILE" ]] && has_command mysql; then
    # shellcheck disable=SC1090
    . "$KH_DB_CRED_FILE"
    mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <"$tmp/database.sql" 2>>"$KH_LOG_FILE" \
      && log_ok "Datenbank wiederhergestellt" \
      || log_warn "Datenbank-Wiederherstellung fehlgeschlagen."
  fi

  (( was_running )) && start_service
  log_ok "Wiederherstellung abgeschlossen"
}
