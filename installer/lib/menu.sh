#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — menu.sh
# Interactive menu and high-level install orchestration.
# =============================================================================
[[ -n "${_KH_MENU_SOURCED:-}" ]] && return 0
_KH_MENU_SOURCED=1

KH_CONF_FILE="${KH_CONF_FILE:-/etc/kumahost/installer.conf}"

# load_config — read persisted installer settings if present.
load_config() {
  if [[ -r "$KH_CONF_FILE" ]]; then
    # shellcheck disable=SC1090
    . "$KH_CONF_FILE"
    log_detail "Konfiguration geladen: ${KH_CONF_FILE}"
  fi
}

# save_config — persist the tunable settings for future runs.
save_config() {
  run mkdir -p "$(dirname "$KH_CONF_FILE")"
  cat >"$KH_CONF_FILE" <<CONF
# KumaHost FiveM Installer — gespeicherte Einstellungen
KH_FX_BASE="${KH_FX_BASE}"
KH_FX_USER="${KH_FX_USER}"
KH_FX_GAME_PORT="${KH_FX_GAME_PORT}"
KH_TXADMIN_PORT="${KH_TXADMIN_PORT}"
KH_PMA_PORT="${KH_PMA_PORT}"
KH_CHANNEL="${KH_CHANNEL:-recommended}"
CONF
  log_ok "Einstellungen gespeichert: ${KH_CONF_FILE}"
}

# do_install WITH_DB WITH_PMA — orchestrate a full installation.
do_install() {
  local with_db="$1" with_pma="$2"
  preflight
  install_base_dependencies
  firewall_check "$KH_FX_GAME_PORT" "$KH_TXADMIN_PORT"
  [[ "$with_db"  == "yes" ]] && install_mariadb
  install_fivem
  setup_txadmin
  install_service
  [[ "$with_pma" == "yes" ]] && install_phpmyadmin
  start_and_verify
  show_txadmin_hint
  printf '\n'; log_ok "Installation abgeschlossen — viel Spaß mit deinem KumaHost FiveM Server!"
}

# advanced_settings — edit ports / paths / channel and persist them.
advanced_settings() {
  while true; do
    printf '\n%s%s── Erweiterte Einstellungen ──%s\n' "$KH_ACCENT" "$KH_BOLD" "$KH_RESET"
    log_detail "Install-Verzeichnis : ${KH_FX_BASE}"
    log_detail "Service-Benutzer    : ${KH_FX_USER}"
    log_detail "Game-Port           : ${KH_FX_GAME_PORT} (TCP/UDP)"
    log_detail "TxAdmin-Port        : ${KH_TXADMIN_PORT}"
    log_detail "phpMyAdmin-Port     : ${KH_PMA_PORT}"
    log_detail "Artefakt-Channel    : ${KH_CHANNEL:-recommended}"
    printf '  %s[1]%s Game-Port  %s[2]%s TxAdmin-Port  %s[3]%s Channel  %s[4]%s Speichern  %s[0]%s Zurück\n' \
      "$KH_ACCENT" "$KH_RESET" "$KH_ACCENT" "$KH_RESET" "$KH_ACCENT" "$KH_RESET" \
      "$KH_ACCENT" "$KH_RESET" "$KH_ACCENT" "$KH_RESET"
    case "$(ask 'Auswahl' '0')" in
      1) local p; p="$(ask 'Neuer Game-Port' "$KH_FX_GAME_PORT")"
         valid_port "$p" && KH_FX_GAME_PORT="$p" || log_warn "Ungültiger Port." ;;
      2) local p; p="$(ask 'Neuer TxAdmin-Port' "$KH_TXADMIN_PORT")"
         valid_port "$p" && KH_TXADMIN_PORT="$p" || log_warn "Ungültiger Port." ;;
      3) case "$(ask 'Channel (recommended/latest)' "${KH_CHANNEL:-recommended}")" in
           latest) KH_CHANNEL=latest ;; *) KH_CHANNEL=recommended ;;
         esac ;;
      4) save_config ;;
      0|"") return 0 ;;
      *) log_warn "Unbekannte Auswahl." ;;
    esac
  done
}

# main_menu — the interactive entrypoint loop.
main_menu() {
  load_config
  while true; do
    kh_banner
    cat <<MENU
  ${KH_ACCENT}[1]${KH_RESET} FiveM installieren
  ${KH_ACCENT}[2]${KH_RESET} FiveM + MariaDB installieren
  ${KH_ACCENT}[3]${KH_RESET} FiveM + MariaDB + phpMyAdmin installieren
  ${KH_ACCENT}[4]${KH_RESET} Server aktualisieren
  ${KH_ACCENT}[5]${KH_RESET} Backup erstellen
  ${KH_ACCENT}[6]${KH_RESET} Backup wiederherstellen
  ${KH_ACCENT}[7]${KH_RESET} Server entfernen
  ${KH_ACCENT}[8]${KH_RESET} Erweiterte Einstellungen
  ${KH_ACCENT}[9]${KH_RESET} Beenden
MENU
    case "$(ask 'Auswahl' '1')" in
      1) do_install no  no  ;;
      2) do_install yes no  ;;
      3) do_install yes yes ;;
      4) require_root; load_config; update_fivem ;;
      5) require_root; create_backup ;;
      6) require_root; restore_backup ;;
      7) require_root; remove_server ;;
      8) advanced_settings ;;
      9|q|Q) log_info "Auf Wiedersehen!"; exit 0 ;;
      *) log_warn "Bitte 1–9 wählen." ;;
    esac
    printf '\n'; read -r -p "$(printf '%sEnter zum Fortfahren …%s' "$KH_DIM" "$KH_RESET")" _ || true
  done
}
