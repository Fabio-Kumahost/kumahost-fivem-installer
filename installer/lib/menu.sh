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

# show_install_summary WITH_DB WITH_PMA — final overview panel after install.
show_install_summary() {
  local with_db="$1" with_pma="$2" ip
  ip="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || echo 'SERVER-IP')"
  kh_panel_top
  kh_panel_line "Installation abgeschlossen"
  kh_panel_divider
  kh_panel_kv "Verzeichnis" "$KH_FX_BASE"
  kh_panel_kv "Benutzer" "$KH_FX_USER"
  kh_panel_kv "Game-Port" "${KH_FX_GAME_PORT} (TCP/UDP)"
  kh_panel_kv "txAdmin" "http://${ip}:${KH_TXADMIN_PORT}"
  [[ "$with_pma" == "yes" ]] && kh_panel_kv "phpMyAdmin" "http://${ip}:${KH_PMA_PORT}"
  kh_panel_kv "Konsole" "kumahost console"
  kh_panel_kv "Start" "via systemd + screen"
  kh_panel_bottom
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
  printf '\n'
  show_txadmin_hint
  [[ "$with_db" == "yes" ]] && show_db_summary
  show_install_summary "$with_db" "$with_pma"
  printf '\n'; log_ok "Viel Spaß mit deinem KumaHost FiveM Server!"
}

# advanced_settings — edit ports / paths / channel and persist them.
advanced_settings() {
  while true; do
    kh_banner
    kh_panel_top
    kh_panel_line "Erweiterte Einstellungen"
    kh_panel_divider
    kh_panel_kv "Verzeichnis" "$KH_FX_BASE"
    kh_panel_kv "Benutzer" "$KH_FX_USER"
    kh_panel_kv "Game-Port" "${KH_FX_GAME_PORT}"
    kh_panel_kv "txAdmin" "${KH_TXADMIN_PORT}"
    kh_panel_kv "phpMyAdmin" "${KH_PMA_PORT}"
    kh_panel_kv "Channel" "${KH_CHANNEL:-recommended}"
    kh_panel_bottom
    kh_menu_item 1 "Game-Port ändern"
    kh_menu_item 2 "txAdmin-Port ändern"
    kh_menu_item 3 "Artefakt-Channel ändern"
    kh_menu_item 4 "Einstellungen speichern"
    kh_menu_item 0 "Zurück"
    printf '\n'
    case "$(ask 'Auswahl' '0')" in
      1) local p; p="$(ask 'Neuer Game-Port' "$KH_FX_GAME_PORT")"
         valid_port "$p" && KH_FX_GAME_PORT="$p" || log_warn "Ungültiger Port." ;;
      2) local p; p="$(ask 'Neuer txAdmin-Port' "$KH_TXADMIN_PORT")"
         valid_port "$p" && KH_TXADMIN_PORT="$p" || log_warn "Ungültiger Port." ;;
      3) case "$(ask 'Channel (recommended/latest)' "${KH_CHANNEL:-recommended}")" in
           latest) KH_CHANNEL=latest ;; *) KH_CHANNEL=recommended ;;
         esac ;;
      4) save_config ;;
      0|"") return 0 ;;
      *) log_warn "Unbekannte Auswahl." ;;
    esac
    printf '\n'; read -r -p "$(printf '  %sEnter zum Fortfahren …%s' "$KH_DIM" "$KH_RESET")" _ || true
  done
}

# main_menu — the interactive entrypoint loop.
main_menu() {
  load_config
  while true; do
    kh_banner
    kh_menu_group "Installation"
    kh_menu_item 1 "FiveM"                       "FXServer + txAdmin"
    kh_menu_item 2 "FiveM + MariaDB"             "inkl. Datenbank"
    kh_menu_item 3 "FiveM + MariaDB + phpMyAdmin" "Komplettpaket"
    kh_menu_group "Verwaltung"
    kh_menu_item 4 "Server aktualisieren"
    kh_menu_item 5 "Backup erstellen"
    kh_menu_item 6 "Backup wiederherstellen"
    kh_menu_item 7 "Server-Konsole"             "screen anhängen"
    kh_menu_group "System"
    kh_menu_item 8 "Server entfernen"
    kh_menu_item 9 "Erweiterte Einstellungen"
    kh_menu_item 0 "Beenden"
    printf '\n'
    case "$(ask 'Auswahl' '1')" in
      1) do_install no  no  ;;
      2) do_install yes no  ;;
      3) do_install yes yes ;;
      4) require_root; load_config; update_fivem ;;
      5) require_root; create_backup ;;
      6) require_root; restore_backup ;;
      7) require_root; attach_console ;;
      8) require_root; remove_server ;;
      9) advanced_settings ;;
      0|q|Q) log_info "Auf Wiedersehen!"; exit 0 ;;
      *) log_warn "Bitte eine gültige Zahl wählen." ;;
    esac
    printf '\n'; read -r -p "$(printf '  %sEnter zum Fortfahren …%s' "$KH_DIM" "$KH_RESET")" _ || true
  done
}
