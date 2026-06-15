#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — mariadb.sh
# Optional MariaDB installation and FiveM database/user provisioning.
# =============================================================================
[[ -n "${_KH_MARIADB_SOURCED:-}" ]] && return 0
_KH_MARIADB_SOURCED=1

KH_DB_NAME="${KH_DB_NAME:-fivem}"
KH_DB_USER="${KH_DB_USER:-fivem}"
KH_DB_CRED_FILE="${KH_DB_CRED_FILE:-${KH_FX_BASE}/.db-credentials}"

# _kh_gen_password — 24-char URL-safe random password.
_kh_gen_password() {
  if has_command openssl; then
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24
  else
    head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24
  fi
}

# install_mariadb — install the server and create the FiveM DB + user.
install_mariadb() {
  log_step "MariaDB installieren"
  install_packages mariadb-server
  run systemctl enable --now mariadb

  local db_pass
  db_pass="$(_kh_gen_password)"

  log_step "Datenbank '${KH_DB_NAME}' und Benutzer '${KH_DB_USER}' anlegen"
  # Idempotent provisioning via the local root socket.
  mysql --protocol=socket -u root <<SQL >>"$KH_LOG_FILE" 2>&1 || die "MariaDB-Provisionierung fehlgeschlagen."
CREATE DATABASE IF NOT EXISTS \`${KH_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${KH_DB_USER}'@'localhost' IDENTIFIED BY '${db_pass}';
ALTER USER '${KH_DB_USER}'@'localhost' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON \`${KH_DB_NAME}\`.* TO '${KH_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

  # Persist credentials with strict permissions for later reference.
  # MariaDB may be installed before install_fivem, so ensure the service
  # user and base directory exist first (both calls are idempotent).
  ensure_fivem_user
  run mkdir -p "$KH_FX_BASE"
  umask 077
  cat >"$KH_DB_CRED_FILE" <<CRED
# KumaHost — MariaDB Zugangsdaten (automatisch generiert)
DB_HOST=localhost
DB_NAME=${KH_DB_NAME}
DB_USER=${KH_DB_USER}
DB_PASSWORD=${db_pass}
# Connection-String für FiveM-Ressourcen (z. B. oxmysql / ghmattimysql):
CONNECTION_STRING=mysql://${KH_DB_USER}:${db_pass}@localhost/${KH_DB_NAME}?charset=utf8mb4
CRED
  run chown "$KH_FX_USER:$KH_FX_USER" "$KH_DB_CRED_FILE"
  run chmod 600 "$KH_DB_CRED_FILE"

  log_ok "MariaDB eingerichtet — Zugangsdaten: ${KH_DB_CRED_FILE}"
  log_detail "Connection-String dort hinterlegt (z. B. für oxmysql in server.cfg)."
}

# show_db_summary — print the stored MariaDB access details at the end of an
# install (e.g. for the phpMyAdmin login). Reads the credentials file written
# by install_mariadb; no-op if it is missing.
show_db_summary() {
  [[ -r "$KH_DB_CRED_FILE" ]] || return 0
  local DB_HOST DB_NAME DB_USER DB_PASSWORD CONNECTION_STRING
  # shellcheck disable=SC1090
  . "$KH_DB_CRED_FILE"
  kh_panel_top
  kh_panel_line "Datenbank-Zugang"
  kh_panel_divider
  kh_panel_kv "Host" "$DB_HOST"
  kh_panel_kv "Datenbank" "$DB_NAME"
  kh_panel_kv "Benutzer" "$DB_USER"
  kh_panel_kv "Passwort" "$DB_PASSWORD"
  kh_panel_bottom
  log_detail "Vollständig (inkl. Connection-String): ${KH_DB_CRED_FILE}"
}
