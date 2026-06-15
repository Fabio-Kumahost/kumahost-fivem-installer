#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — checks.sh
# OS detection and automatic system pre-flight checks.
# =============================================================================
[[ -n "${_KH_CHECKS_SOURCED:-}" ]] && return 0
_KH_CHECKS_SOURCED=1

# Supported distributions: "<id> <version>" → human label.
# Debian 12/13, Ubuntu 22.04/24.04 per project spec.
_kh_supported() {
  case "$1:$2" in
    debian:12) echo "Debian 12 (Bookworm)" ;;
    debian:13) echo "Debian 13 (Trixie)" ;;
    ubuntu:22.04) echo "Ubuntu 22.04 LTS (Jammy)" ;;
    ubuntu:24.04) echo "Ubuntu 24.04 LTS (Noble)" ;;
    *) return 1 ;;
  esac
}

# detect_os — populates KH_OS_ID / KH_OS_VERSION / KH_OS_LABEL globals.
detect_os() {
  [[ -r /etc/os-release ]] || die "Konnte /etc/os-release nicht lesen — Distribution unbekannt."
  # shellcheck disable=SC1091
  . /etc/os-release
  KH_OS_ID="${ID:-unknown}"
  # VERSION_ID for Ubuntu is e.g. 24.04, for Debian e.g. 12.
  KH_OS_VERSION="${VERSION_ID:-unknown}"
  if KH_OS_LABEL="$(_kh_supported "$KH_OS_ID" "$KH_OS_VERSION")"; then
    log_ok "Erkanntes System: ${KH_OS_LABEL}"
    return 0
  fi
  log_warn "Nicht offiziell unterstützt: ${PRETTY_NAME:-$KH_OS_ID $KH_OS_VERSION}"
  log_detail "Unterstützt: Debian 12/13, Ubuntu 22.04/24.04."
  if ! confirm "Trotzdem auf eigenes Risiko fortfahren"; then
    die "Installation abgebrochen — nicht unterstütztes System." 2
  fi
  KH_OS_LABEL="${PRETTY_NAME:-$KH_OS_ID $KH_OS_VERSION}"
}

# check_arch — FiveM artifacts are x86_64 only.
check_arch() {
  local arch; arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) log_ok "Architektur: ${arch}" ;;
    *) die "FiveM benötigt x86_64 — gefunden: ${arch}." 3 ;;
  esac
}

# check_memory — warn (do not block) when under the recommended 2 GB RAM.
check_memory() {
  local kb mb
  kb="$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  mb=$(( kb / 1024 ))
  if (( mb < 1024 )); then
    log_warn "Nur ${mb} MB RAM erkannt — FiveM empfiehlt mindestens 2 GB."
  else
    log_ok "Arbeitsspeicher: ${mb} MB"
  fi
}

# check_disk PATH MIN_GB — ensure at least MIN_GB of free space at PATH.
check_disk() {
  local path="$1" min_gb="${2:-5}" avail_gb
  avail_gb="$(df -BG --output=avail "$path" 2>/dev/null | tail -1 | tr -dc '0-9')"
  avail_gb="${avail_gb:-0}"
  if (( avail_gb < min_gb )); then
    log_warn "Nur ${avail_gb} GB frei unter ${path} (empfohlen: ${min_gb} GB)."
    confirm "Trotzdem fortfahren" || die "Zu wenig Speicherplatz." 4
  else
    log_ok "Freier Speicher unter ${path}: ${avail_gb} GB"
  fi
}

# check_internet — verify outbound HTTPS works before downloading anything.
check_internet() {
  if has_command curl && curl -fsSL --max-time 10 -o /dev/null https://runtime.fivem.net/ 2>/dev/null; then
    log_ok "Internetverbindung verfügbar"
  else
    die "Keine Verbindung zu runtime.fivem.net — Netzwerk/DNS prüfen." 5
  fi
}

# preflight — run the full automatic system check suite.
preflight() {
  log_step "Automatische Systemprüfung"
  require_root
  detect_os
  check_arch
  check_memory
  # Check the filesystem that will actually hold the install (base dir parent).
  local disk_path; disk_path="$(dirname "${KH_FX_BASE:-/home/fivem}")"
  [[ -d "$disk_path" ]] || disk_path="/"
  check_disk "$disk_path" 5
  check_internet
  log_ok "Systemprüfung abgeschlossen"
}
