#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — install.sh (entrypoint)
#
# One-line install:
#   bash <(curl -sSL https://raw.githubusercontent.com/Fabio-Kumahost/kumahost-fivem-installer/main/install.sh)
#
# When piped through curl the script has no local libraries, so it bootstraps
# by downloading the repository, then re-executes from disk. When run from a
# clone it sources the libraries directly.
# =============================================================================
set -Eeuo pipefail

KH_REPO_OWNER="${KH_REPO_OWNER:-Fabio-Kumahost}"
KH_REPO_NAME="${KH_REPO_NAME:-kumahost-fivem-installer}"
KH_REPO_BRANCH="${KH_REPO_BRANCH:-main}"
KH_TARBALL="https://github.com/${KH_REPO_OWNER}/${KH_REPO_NAME}/archive/refs/heads/${KH_REPO_BRANCH}.tar.gz"

# Resolve the directory of this script when it lives on disk (not via curl).
_self="${BASH_SOURCE[0]:-}"
if [[ -n "$_self" && -f "$_self" ]]; then
  KH_ROOT="$(cd "$(dirname "$_self")" && pwd)"
else
  KH_ROOT=""
fi

# ---------------------------------------------------------------------------
# Bootstrap: if libraries are not next to us, download the repo and re-exec.
# ---------------------------------------------------------------------------
if [[ -z "$KH_ROOT" || ! -f "$KH_ROOT/installer/lib/common.sh" ]]; then
  command -v curl >/dev/null 2>&1 || { echo "curl wird benötigt." >&2; exit 1; }
  command -v tar  >/dev/null 2>&1 || { echo "tar wird benötigt."  >&2; exit 1; }
  echo "› Lade KumaHost FiveM Installer herunter …"
  _boot="$(mktemp -d)"
  trap 'rm -rf "$_boot"' EXIT
  if ! curl -fsSL "$KH_TARBALL" | tar -xz -C "$_boot" 2>/dev/null; then
    echo "Konnte das Repository nicht laden: $KH_TARBALL" >&2
    exit 1
  fi
  KH_ROOT="$(find "$_boot" -maxdepth 1 -type d -name "${KH_REPO_NAME}-*" | head -1)"
  [[ -f "$KH_ROOT/install.sh" ]] || { echo "Bootstrap fehlgeschlagen." >&2; exit 1; }
  exec bash "$KH_ROOT/install.sh" "$@"
fi

# ---------------------------------------------------------------------------
# Local run: configure logging, load libraries, launch the menu.
# ---------------------------------------------------------------------------
export KH_LOG_FILE="${KH_LOG_FILE:-/var/log/kumahost-installer.log}"
# Ensure the log file is writable; fall back to a temp file if not root yet.
if ! touch "$KH_LOG_FILE" 2>/dev/null; then
  KH_LOG_FILE="$(mktemp -t kumahost-installer.XXXXXX.log)"
  export KH_LOG_FILE
fi

export KH_ROOT
export KH_TEMPLATE_DIR="$KH_ROOT/installer/templates"
LIB="$KH_ROOT/installer/lib"

# Order matters: common first, then leaf modules, orchestration last.
# shellcheck source=/dev/null
for module in common checks deps firewall fivem txadmin mariadb phpmyadmin \
              service backup update uninstall menu; do
  source "$LIB/${module}.sh"
done

# A single trap converts unexpected errors into a clear diagnostic line.
trap 'log_error "Unerwarteter Fehler in Zeile ${LINENO} (Exit-Code $?). Log: ${KH_LOG_FILE}"' ERR

# Non-interactive subcommands for automation / the API backend.
case "${1:-menu}" in
  install)        require_root; load_config; do_install "${2:-no}" "${3:-no}" ;;
  update)         require_root; load_config; update_fivem ;;
  backup)         require_root; load_config; create_backup ;;
  restore)        require_root; load_config; restore_backup "${2:-}" ;;
  remove)         require_root; load_config; remove_server ;;
  start)          require_root; load_config; start_service ;;
  stop)           require_root; load_config; stop_service ;;
  restart)        require_root; load_config; restart_service ;;
  console)        require_root; load_config; attach_console ;;
  panel)          require_root; load_config; install_webpanel ;;
  status)         load_config; service_status ;;
  menu|"")        main_menu ;;
  -h|--help|help)
    cat <<USAGE
KumaHost FiveM Installer
  install [db] [pma]   Installation (db=yes für MariaDB, pma=yes für phpMyAdmin)
  update               Server-Artefakt aktualisieren
  backup               Backup erstellen
  restore [archiv]     Backup wiederherstellen
  remove               Server entfernen
  start|stop|restart   Service steuern
  console              Mit der Server-Konsole (screen) verbinden
  panel                KumaHost Webpanel installieren
  status               Service-Status
  menu                 Interaktives Menü (Standard)
USAGE
    ;;
  *) echo "Unbekannter Befehl: $1 (siehe --help)" >&2; exit 1 ;;
esac
