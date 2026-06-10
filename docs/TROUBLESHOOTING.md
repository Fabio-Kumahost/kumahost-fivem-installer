# Troubleshooting

All installer actions are logged to `/var/log/kumahost-installer.log`
(panel installer: `/var/log/kumahost-panel-install.log`).

## Installer

**"Bitte als root ausführen"** — run with `sudo`.

**"Keine Verbindung zu runtime.fivem.net"** — check DNS/outbound HTTPS:
```bash
curl -I https://runtime.fivem.net/
```

**"Archiv ist beschädigt"** — the download failed integrity validation.
Re-run; if it persists, try the other channel (`KH_CHANNEL=latest`).

**Server won't start / health check fails** — the installer prints a diagnosis.
Dig deeper with:
```bash
systemctl status fivem
journalctl -u fivem -n 100 --no-pager
tail -n 100 /var/log/fivem/server.log
```
Common causes: missing/invalid `sv_licenseKey` in `server.cfg`, or the game
port already in use.

**TxAdmin not reachable on :40120** — confirm the port is listening and open:
```bash
ss -ltnp | grep 40120
ufw status        # or: firewall-cmd --list-ports
```

## Webpanel / API

**502 Bad Gateway** — the API service is down:
```bash
systemctl status kumahost-api
journalctl -u kumahost-api -n 80 --no-pager
```

**"JWT_SECRET fehlt oder ist zu kurz"** — set a strong secret in
`/opt/kumahost/api/.env` (`openssl rand -hex 48`) and restart the service.

**Login works but actions return 403 (CSRF)** — the panel must send the
`X-CSRF-Token` header. Hard-refresh the page so a fresh `kh_csrf` cookie is
issued. For Bearer/API clients, CSRF does not apply.

**Server controls fail with a sudo/permission error** — verify the allowlist:
```bash
sudo visudo -cf /etc/sudoers.d/kumahost
sudo -u kumahost sudo -n systemctl is-active fivem
```

**better-sqlite3 build error during `npm install`** — install build tools:
```bash
sudo apt-get install -y build-essential python3
```

**CPU/RAM shows 0** — host metrics read from `/proc`; this is expected on
non-Linux hosts and inside restricted containers.

## Reset

```bash
sudo bash install.sh remove        # remove FiveM (keeps backups by default)
sudo systemctl disable --now kumahost-api && sudo rm -rf /opt/kumahost
```
