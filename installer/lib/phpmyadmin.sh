#!/usr/bin/env bash
# =============================================================================
# KumaHost FiveM Installer — phpmyadmin.sh
# Optional phpMyAdmin install served by nginx + php-fpm on a dedicated port.
# =============================================================================
[[ -n "${_KH_PMA_SOURCED:-}" ]] && return 0
_KH_PMA_SOURCED=1

KH_PMA_PORT="${KH_PMA_PORT:-8080}"
KH_PMA_ROOT="/usr/share/phpmyadmin"
KH_PMA_NGINX="/etc/nginx/sites-available/kumahost-phpmyadmin.conf"

# install_phpmyadmin — install phpMyAdmin and expose it via nginx.
install_phpmyadmin() {
  log_step "phpMyAdmin installieren"
  install_packages nginx php-fpm php-mysqli php-mbstring php-zip php-gd php-json phpmyadmin

  # Determine the active php-fpm socket (version-agnostic).
  local fpm_sock
  fpm_sock="$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)"
  [[ -n "$fpm_sock" ]] || die "php-fpm Socket nicht gefunden — Installation prüfen."

  cat >"$KH_PMA_NGINX" <<NGINX
# KumaHost — phpMyAdmin (auto-generated)
server {
    listen ${KH_PMA_PORT};
    listen [::]:${KH_PMA_PORT};
    server_name _;
    root ${KH_PMA_ROOT};
    index index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${fpm_sock};
    }
    location ~ /\.ht { deny all; }
}
NGINX

  run ln -sf "$KH_PMA_NGINX" /etc/nginx/sites-enabled/kumahost-phpmyadmin.conf
  run nginx -t
  run systemctl reload nginx
  open_port "$KH_PMA_PORT" tcp

  local ip
  ip="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || echo 'SERVER-IP')"
  log_ok "phpMyAdmin erreichbar: http://${ip}:${KH_PMA_PORT}"
  log_detail "Login mit dem MariaDB-Benutzer (siehe ${KH_DB_CRED_FILE})."
}
