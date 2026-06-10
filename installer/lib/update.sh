#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — update.sh (library)
# Safe artifact updates: backup → stop → swap → validate → start → verify.
# =============================================================================
[[ -n "${_KH_UPDATE_SOURCED:-}" ]] && return 0
_KH_UPDATE_SOURCED=1

# update_fivem — replace the FXServer artifact, keeping server-data intact.
update_fivem() {
  log_step "Server aktualisieren"
  [[ -d "$KH_FX_ARTIFACT_DIR" ]] || die "Keine bestehende Installation unter ${KH_FX_ARTIFACT_DIR}."

  local current url
  current="$(installed_version)"
  log_detail "Aktuell installiert: ${current}"
  url="$(choose_artifact_url)"
  log_detail "Ziel: ${url}"

  if [[ "$url" == "$(cat "$KH_FX_BASE/.artifact-url" 2>/dev/null)" ]] && ! confirm "Gleiche Version — trotzdem neu installieren"; then
    log_ok "Bereits aktuell — nichts zu tun."
    return 0
  fi

  # Always create a safety backup before touching the artifact.
  create_backup >/dev/null || log_warn "Backup vor Update fehlgeschlagen — fahre vorsichtig fort."

  local was_running=0
  systemctl is-active --quiet "$KH_SERVICE_NAME" 2>/dev/null && { was_running=1; stop_service; }

  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  log_step "Lade neues Artefakt"
  curl -fL --retry 3 --retry-delay 2 -o "$tmp/fx.tar.xz" "$url" >>"$KH_LOG_FILE" 2>&1 \
    || die "Download fehlgeschlagen: $url"
  validate_archive "$tmp/fx.tar.xz"

  # Swap atomically: keep the old artifact until the new one is in place.
  local backup_artifact="${KH_FX_ARTIFACT_DIR}.old"
  run rm -rf "$backup_artifact"
  run mv "$KH_FX_ARTIFACT_DIR" "$backup_artifact"
  run mkdir -p "$KH_FX_ARTIFACT_DIR"
  if ! tar -xJf "$tmp/fx.tar.xz" -C "$KH_FX_ARTIFACT_DIR" >>"$KH_LOG_FILE" 2>&1; then
    log_error "Entpacken fehlgeschlagen — stelle vorherige Version wieder her."
    run rm -rf "$KH_FX_ARTIFACT_DIR"
    run mv "$backup_artifact" "$KH_FX_ARTIFACT_DIR"
    die "Update abgebrochen — alte Version aktiv."
  fi
  run chmod +x "$KH_FX_ARTIFACT_DIR/run.sh"
  printf '%s\n' "$url" >"$KH_FX_BASE/.artifact-url"
  run chown -R "$KH_FX_USER:$KH_FX_USER" "$KH_FX_BASE"
  run rm -rf "$backup_artifact"
  log_ok "Artefakt aktualisiert: $(installed_version)"

  (( was_running )) && start_and_verify
}
