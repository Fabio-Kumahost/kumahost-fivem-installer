#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — update.sh
# Convenience wrapper. Updates the installed FiveM artifact.
#   bash <(curl -sSL https://raw.githubusercontent.com/Fabio-Kumahost/kumahost-fivem-installer/main/update.sh)
# =============================================================================
set -Eeuo pipefail

KH_REPO_OWNER="${KH_REPO_OWNER:-Fabio-Kumahost}"
KH_REPO_NAME="${KH_REPO_NAME:-kumahost-fivem-installer}"
KH_REPO_BRANCH="${KH_REPO_BRANCH:-main}"

_self="${BASH_SOURCE[0]:-}"
if [[ -n "$_self" && -f "$_self" && -f "$(dirname "$_self")/install.sh" ]]; then
  # Running from a clone — delegate to the local entrypoint.
  exec bash "$(cd "$(dirname "$_self")" && pwd)/install.sh" update "$@"
fi

# Piped via curl — bootstrap the repository, then run the update subcommand.
tarball="https://github.com/${KH_REPO_OWNER}/${KH_REPO_NAME}/archive/refs/heads/${KH_REPO_BRANCH}.tar.gz"
boot="$(mktemp -d)"; trap 'rm -rf "$boot"' EXIT
echo "› Lade KumaHost FiveM Installer (Update) …"
curl -fsSL "$tarball" | tar -xz -C "$boot"
root="$(find "$boot" -maxdepth 1 -type d -name "${KH_REPO_NAME}-*" | head -1)"
exec bash "$root/install.sh" update "$@"
