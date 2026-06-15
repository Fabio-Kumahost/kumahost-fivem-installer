#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Webpanel — install-panel.sh
# Installs the API + webpanel: Node.js, nginx, database, admin user, sudoers,
# systemd service and (optionally) a Let's Encrypt certificate via certbot.
#
# Run from a clone of the repository, as root:
#   sudo bash deploy/install-panel.sh
# =============================================================================
set -Eeuo pipefail

# Resolve repository root (this script lives in <root>/deploy).
KH_SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Reuse the installer's logging/colours/helpers.
export KH_LOG_FILE="/var/log/kumahost-panel-install.log"
touch "$KH_LOG_FILE" 2>/dev/null || KH_LOG_FILE="$(mktemp)"
# shellcheck source=/dev/null
source "$KH_SRC_ROOT/installer/lib/common.sh"

KH_PREFIX="/opt/kumahost"
KH_USER="kumahost"
KH_API_PORT="${KH_API_PORT:-8787}"
KH_NODE_MAJOR="${KH_NODE_MAJOR:-20}"

main() {
  kh_banner
  require_root
  log_step "KumaHost Webpanel-Installation"

  install_prerequisites
  install_nodejs
  create_user
  deploy_files
  install_api_dependencies
  configure_env
  init_database
  create_admin_user
  configure_sudoers
  install_systemd_service
  configure_nginx
  maybe_setup_ssl
  summary
}

# --- Steps -----------------------------------------------------------------

install_prerequisites() {
  export DEBIAN_FRONTEND=noninteractive
  log_step "Basis-Pakete installieren"
  run apt-get update -y
  run apt-get install -y --no-install-recommends curl ca-certificates gnupg nginx openssl rsync
}

install_nodejs() {
  if has_command node && [[ "$(node -p 'process.versions.node.split(".")[0]')" -ge 18 ]]; then
    log_ok "Node.js bereits vorhanden: $(node -v)"
    return 0
  fi
  log_step "Node.js ${KH_NODE_MAJOR}.x installieren (NodeSource)"
  curl -fsSL "https://deb.nodesource.com/setup_${KH_NODE_MAJOR}.x" -o /tmp/nodesource_setup.sh \
    || die "Konnte NodeSource-Setup nicht laden."
  run bash /tmp/nodesource_setup.sh
  run apt-get install -y nodejs
  log_ok "Node.js installiert: $(node -v)"
}

create_user() {
  if id "$KH_USER" >/dev/null 2>&1; then
    log_detail "Benutzer ${KH_USER} existiert bereits."
  else
    run useradd --system --create-home --home-dir "$KH_PREFIX" --shell /usr/sbin/nologin "$KH_USER"
    log_ok "Service-Benutzer ${KH_USER} angelegt"
  fi
}

deploy_files() {
  log_step "Dateien nach ${KH_PREFIX} kopieren"
  run mkdir -p "$KH_PREFIX"
  # Sync source while excluding dev/build artefacts.
  run rsync -a --delete \
    --exclude '.git' --exclude 'node_modules' --exclude 'api/data' \
    --exclude 'api/.env' \
    "$KH_SRC_ROOT"/ "$KH_PREFIX"/
  run mkdir -p "$KH_PREFIX/api/data"
  run chown -R "$KH_USER:$KH_USER" "$KH_PREFIX"
}

install_api_dependencies() {
  log_step "API-Abhängigkeiten installieren"
  ( cd "$KH_PREFIX/api" && sudo -u "$KH_USER" npm install --omit=dev --no-audit --no-fund ) \
    >>"$KH_LOG_FILE" 2>&1 || die "npm install fehlgeschlagen (siehe $KH_LOG_FILE)."
  log_ok "Abhängigkeiten installiert"
}

configure_env() {
  local env_file="$KH_PREFIX/api/.env"
  if [[ -f "$env_file" ]]; then
    log_detail ".env existiert bereits — bleibt unverändert."
    return 0
  fi
  log_step "Konfiguration (.env) erzeugen"
  local secret; secret="$(openssl rand -hex 48)"
  local server_name="${KH_SERVER_NAME:-$(ask 'Domain/Hostname des Panels (oder _ für IP)' '_')}"
  KH_SERVER_NAME="$server_name"
  install -o "$KH_USER" -g "$KH_USER" -m 600 /dev/null "$env_file"
  cat >"$env_file" <<ENV
NODE_ENV=production
PORT=${KH_API_PORT}
HOST=127.0.0.1
CORS_ORIGIN=http://${server_name}
JWT_SECRET=${secret}
JWT_EXPIRES_IN=2h
BCRYPT_ROUNDS=12
DB_PATH=./data/kumahost.db
INSTALLER_PATH=${KH_PREFIX}/install.sh
PRIVILEGE_PREFIX=sudo
FIVEM_SERVICE=fivem
FIVEM_BASE=/home/fivem
FIVEM_LOG=/var/log/fivem/server.log
TXADMIN_PORT=40120
SECURE_COOKIES=false
ENV
  run chown "$KH_USER:$KH_USER" "$env_file"
  log_ok "Konfiguration geschrieben: ${env_file}"
}

init_database() {
  log_step "Datenbank initialisieren"
  ( cd "$KH_PREFIX/api" && sudo -u "$KH_USER" npm run init-db ) >>"$KH_LOG_FILE" 2>&1 \
    || die "DB-Initialisierung fehlgeschlagen."
  log_ok "Datenbank bereit"
}

create_admin_user() {
  log_step "Admin-Benutzer anlegen"
  local user pass
  user="${KH_ADMIN_USER:-$(ask 'Admin-Benutzername' 'admin')}"
  pass="${KH_ADMIN_PASSWORD:-}"
  if [[ -z "$pass" ]]; then
    read -r -s -p "$(printf 'Admin-Passwort (min. 8 Zeichen): ')" pass; echo
  fi
  [[ ${#pass} -ge 8 ]] || die "Passwort zu kurz (min. 8 Zeichen)."
  ( cd "$KH_PREFIX/api" && sudo -u "$KH_USER" node src/scripts/create-admin.js "$user" "$pass" admin ) \
    >>"$KH_LOG_FILE" 2>&1 || die "Admin-Erstellung fehlgeschlagen."
  log_ok "Admin-Benutzer '${user}' erstellt"
}

configure_sudoers() {
  log_step "Sudoers-Regeln für ${KH_USER} einrichten"
  # Allow the panel user to control ONLY the fivem service and the installer.
  local sudoers="/etc/sudoers.d/kumahost"
  cat >"$sudoers" <<SUDO
# KumaHost panel — least-privilege command allowlist for the API service user.
${KH_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl start fivem, /usr/bin/systemctl stop fivem, /usr/bin/systemctl restart fivem, /usr/bin/systemctl is-active fivem, /usr/bin/systemctl status fivem
${KH_USER} ALL=(root) NOPASSWD: /usr/bin/bash ${KH_PREFIX}/install.sh update, /usr/bin/bash ${KH_PREFIX}/install.sh backup, /usr/bin/bash ${KH_PREFIX}/install.sh restore *
SUDO
  run chmod 440 "$sudoers"
  run visudo -cf "$sudoers"
  log_ok "Sudoers-Regeln validiert"
}

install_systemd_service() {
  log_step "systemd-Service installieren"
  run cp "$KH_PREFIX/deploy/systemd/kumahost-api.service" /etc/systemd/system/kumahost-api.service
  run systemctl daemon-reload
  run systemctl enable --now kumahost-api
  log_ok "kumahost-api Service läuft"
}

configure_nginx() {
  log_step "nginx konfigurieren"
  local conf="/etc/nginx/sites-available/kumahost-panel.conf"
  sed -e "s#__KH_SERVER_NAME__#${KH_SERVER_NAME:-_}#g" \
      -e "s#__KH_API_PORT__#${KH_API_PORT}#g" \
      "$KH_PREFIX/deploy/nginx/kumahost-panel.conf" >"$conf"
  run ln -sf "$conf" /etc/nginx/sites-enabled/kumahost-panel.conf
  rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
  run nginx -t
  run systemctl reload nginx
  open_port_compat 80
  log_ok "nginx aktiv"
}

# open_port_compat — best-effort firewall opening (ufw/firewalld).
open_port_compat() {
  local port="$1"
  if has_command ufw && ufw status >/dev/null 2>&1; then
    run ufw allow "${port}/tcp"
  elif has_command firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    run firewall-cmd --permanent --add-port="${port}/tcp" && run firewall-cmd --reload
  fi
}

maybe_setup_ssl() {
  [[ "${KH_SERVER_NAME:-_}" == "_" ]] && { log_detail "Kein Domainname — SSL übersprungen."; return 0; }
  if ! confirm "Jetzt ein Let's-Encrypt-SSL-Zertifikat via certbot einrichten"; then
    log_detail "SSL übersprungen — später: certbot --nginx -d ${KH_SERVER_NAME}"
    return 0
  fi
  run apt-get install -y certbot python3-certbot-nginx
  if certbot --nginx -d "$KH_SERVER_NAME" --non-interactive --agree-tos \
       -m "${KH_SSL_EMAIL:-admin@${KH_SERVER_NAME}}" --redirect >>"$KH_LOG_FILE" 2>&1; then
    # With HTTPS active, enable Secure cookies.
    sed -i 's/^SECURE_COOKIES=.*/SECURE_COOKIES=true/' "$KH_PREFIX/api/.env"
    run systemctl restart kumahost-api
    log_ok "SSL aktiv für ${KH_SERVER_NAME}"
  else
    log_warn "certbot fehlgeschlagen — Panel bleibt über HTTP erreichbar."
  fi
}

summary() {
  local ip; ip="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || echo 'SERVER-IP')"
  local host="${KH_SERVER_NAME:-$ip}"; [[ "$host" == "_" ]] && host="$ip"
  printf '\n'
  log_ok "KumaHost Webpanel installiert!"
  log_detail "Panel:   http://${host}/"
  log_detail "API:     http://127.0.0.1:${KH_API_PORT}/api/system/health"
  log_detail "Service: systemctl status kumahost-api"
  log_detail "Logs:    journalctl -u kumahost-api -f"
}

main "$@"
