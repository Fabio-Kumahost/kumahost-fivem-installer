#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — deps.sh
# Automatic dependency installation via apt.
# =============================================================================
[[ -n "${_KH_DEPS_SOURCED:-}" ]] && return 0
_KH_DEPS_SOURCED=1

# Base packages every FiveM host needs.
KH_BASE_PACKAGES=(
  curl wget ca-certificates xz-utils tar
  screen git unzip gnupg lsb-release
)

# _kh_apt_update — refresh package lists at most once per run.
_kh_apt_update() {
  [[ -n "${_KH_APT_UPDATED:-}" ]] && return 0
  log_step "Paketquellen aktualisieren"
  export DEBIAN_FRONTEND=noninteractive
  run apt-get update -y
  _KH_APT_UPDATED=1
}

# install_packages PKG... — install only the packages that are missing.
install_packages() {
  local pkg missing=()
  for pkg in "$@"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} == 0 )); then
    log_ok "Alle Pakete bereits installiert: $*"
    return 0
  fi
  _kh_apt_update
  log_step "Installiere: ${missing[*]}"
  export DEBIAN_FRONTEND=noninteractive
  run apt-get install -y --no-install-recommends "${missing[@]}"
  log_ok "Pakete installiert: ${missing[*]}"
}

# install_base_dependencies — the standard FiveM dependency set.
install_base_dependencies() {
  log_step "Automatische Dependency-Installation"
  install_packages "${KH_BASE_PACKAGES[@]}"
}
