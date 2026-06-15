#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — fivem.sh
# FiveM (FXServer) artifact discovery, validated download and installation.
# =============================================================================
[[ -n "${_KH_FIVEM_SOURCED:-}" ]] && return 0
_KH_FIVEM_SOURCED=1

# Upstream sources.
KH_FX_CHANGELOG="https://changelogs-live.fivem.net/api/changelog/versions/linux/server"
KH_FX_ARTIFACTS="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master"

# Install layout — overridable via environment before sourcing.
KH_FX_BASE="${KH_FX_BASE:-/home/fivem}"         # server data + cfg
KH_FX_ARTIFACT_DIR="${KH_FX_ARTIFACT_DIR:-${KH_FX_BASE}/artifact}"
KH_FX_DATA_DIR="${KH_FX_DATA_DIR:-${KH_FX_BASE}/server-data}"
KH_FX_USER="${KH_FX_USER:-fivem}"

# _kh_fetch URL — print URL body to stdout or fail.
_kh_fetch() { curl -fsSL --max-time 30 "$1"; }

# _kh_json KEY < json — extract a top-level string value without jq dependency.
_kh_json() {
  local key="$1"
  grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/'
}

# resolve_artifact CHANNEL — echo the download URL for "latest" or "recommended".
resolve_artifact() {
  local channel="$1" json url
  json="$(_kh_fetch "$KH_FX_CHANGELOG")" \
    || die "Konnte FiveM-Changelog nicht laden ($KH_FX_CHANGELOG)."
  case "$channel" in
    latest)      url="$(printf '%s' "$json" | _kh_json latest_download)" ;;
    recommended) url="$(printf '%s' "$json" | _kh_json recommended_download)" ;;
    *) die "Unbekannter Channel: $channel" ;;
  esac
  [[ "$url" == https://* ]] || die "Keine gültige Artefakt-URL für '$channel' gefunden."
  printf '%s' "$url"
}

# show_versions — print the currently advertised latest/recommended builds.
show_versions() {
  local json
  json="$(_kh_fetch "$KH_FX_CHANGELOG")" || { log_warn "Versionsinfo nicht abrufbar."; return 1; }
  log_detail "Empfohlen (recommended): $(printf '%s' "$json" | _kh_json recommended)"
  log_detail "Neueste   (latest):      $(printf '%s' "$json" | _kh_json latest)"
}

# choose_artifact_url — interactive selection → echoes a download URL.
# Honours KH_CHANNEL (latest|recommended|custom) and KH_CUSTOM_BUILD for
# non-interactive runs.
choose_artifact_url() {
  local choice="${KH_CHANNEL:-}" build
  if [[ -z "$choice" ]]; then
    # Informational output must go to stderr — this function's stdout is
    # captured by url="$(choose_artifact_url)" and must contain only the URL.
    show_versions >&2 || true
    printf '\n  %s[1]%s Recommended  %s[2]%s Latest  %s[3]%s Benutzerdefiniert\n' \
      "$KH_ACCENT" "$KH_RESET" "$KH_ACCENT" "$KH_RESET" "$KH_ACCENT" "$KH_RESET" >&2
    case "$(ask 'Artefakt-Version wählen' '1')" in
      1) choice=recommended ;; 2) choice=latest ;; 3) choice=custom ;;
      *) choice=recommended ;;
    esac
  fi
  case "$choice" in
    latest|recommended) resolve_artifact "$choice" ;;
    custom)
      build="${KH_CUSTOM_BUILD:-$(ask 'Build-Ordner (z. B. 12000-abcdef…)' '')}"
      [[ -n "$build" ]] || die "Kein benutzerdefinierter Build angegeben."
      printf '%s/%s/fx.tar.xz' "$KH_FX_ARTIFACTS" "$build" ;;
    *) die "Ungültiger Channel: $choice" ;;
  esac
}

# validate_archive FILE — confirm the download is a real, intact xz tarball.
validate_archive() {
  local file="$1" size
  [[ -s "$file" ]] || die "Download ist leer: $file"
  size="$(stat -c%s "$file" 2>/dev/null || echo 0)"
  (( size > 1000000 )) || die "Download zu klein (${size} Bytes) — vermutlich fehlerhaft."
  xz -t "$file" 2>/dev/null || die "Archiv ist beschädigt (xz-Integritätsprüfung fehlgeschlagen)."
  tar -tJf "$file" >/dev/null 2>&1 || die "Archiv enthält kein gültiges tar."
  log_ok "Download-Validierung erfolgreich ($(( size / 1024 / 1024 )) MB)"
}

# ensure_fivem_user — create the unprivileged service account if needed.
ensure_fivem_user() {
  if id "$KH_FX_USER" >/dev/null 2>&1; then
    log_detail "Benutzer ${KH_FX_USER} existiert bereits."
  else
    run useradd --system --create-home --home-dir "$KH_FX_BASE" \
      --shell /usr/sbin/nologin "$KH_FX_USER"
    log_ok "Service-Benutzer ${KH_FX_USER} angelegt"
  fi
}

# install_fivem — download, validate and unpack the selected artifact.
install_fivem() {
  log_step "Automatische FiveM-Installation"
  local url tmp
  url="$(choose_artifact_url)"
  log_detail "Quelle: ${url}"

  ensure_fivem_user
  run mkdir -p "$KH_FX_ARTIFACT_DIR" "$KH_FX_DATA_DIR"

  # Explicit cleanup instead of a RETURN trap: a RETURN trap set here leaks
  # past this function and re-fires on later returns (e.g. do_install), where
  # $tmp is unbound under `set -u`. die() exits the process, so it would never
  # have run on error anyway — clean up by hand on each exit path.
  tmp="$(mktemp -d)"
  log_step "Lade Artefakt herunter"
  if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp/fx.tar.xz" "$url" >>"$KH_LOG_FILE" 2>&1; then
    rm -rf "$tmp"
    die "Download fehlgeschlagen: $url"
  fi
  validate_archive "$tmp/fx.tar.xz"

  log_step "Entpacke nach ${KH_FX_ARTIFACT_DIR}"
  run tar -xJf "$tmp/fx.tar.xz" -C "$KH_FX_ARTIFACT_DIR"
  rm -rf "$tmp"
  [[ -f "$KH_FX_ARTIFACT_DIR/run.sh" ]] || die "run.sh fehlt — Artefakt unvollständig."
  run chmod +x "$KH_FX_ARTIFACT_DIR/run.sh"

  # Record the installed source URL for later update/version reporting.
  printf '%s\n' "$url" >"$KH_FX_BASE/.artifact-url"
  run chown -R "$KH_FX_USER:$KH_FX_USER" "$KH_FX_BASE"
  log_ok "FiveM installiert unter ${KH_FX_BASE}"
}

# installed_version — best-effort current build number from the stored URL.
installed_version() {
  [[ -r "$KH_FX_BASE/.artifact-url" ]] || { echo "unbekannt"; return; }
  sed -E 's#.*/master/([^/]+)/fx.tar.xz#\1#' "$KH_FX_BASE/.artifact-url"
}
