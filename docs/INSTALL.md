# Installation Guide

## Requirements

- **OS:** Debian 12/13 or Ubuntu 22.04/24.04 (x86_64)
- **RAM:** 2 GB+ recommended
- **Access:** root / `sudo`
- A FiveM **License Key** from <https://keymaster.fivem.net> (can be added later)

---

## 1. Install the FiveM server (one-liner)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Fabio-Kumahost/kumahost-fivem-installer/main/install.sh)
```

This downloads the installer and opens the interactive menu:

```
[1] FiveM installieren
[2] FiveM + MariaDB installieren
[3] FiveM + MariaDB + phpMyAdmin installieren
[4] Server aktualisieren
[5] Backup erstellen
[6] Backup wiederherstellen
[7] Server entfernen
[8] Erweiterte Einstellungen
[9] Beenden
```

Pick **1**, **2**, or **3**. The installer then automatically:

1. Runs system checks (OS, arch, RAM, disk, connectivity).
2. Installs dependencies via `apt`.
3. Checks/opens firewall ports (`ufw`/`firewalld`).
4. Lets you choose the artifact: **Recommended**, **Latest**, or a custom build.
5. Downloads and **validates** the artifact.
6. Prepares server-data + a starter `server.cfg` and sets up TxAdmin.
7. Creates and enables a `systemd` service (`fivem`).
8. Starts the server and runs a **health check**.

### Non-interactive

```bash
# FiveM only
sudo bash install.sh install
# FiveM + MariaDB
sudo bash install.sh install yes
# FiveM + MariaDB + phpMyAdmin
sudo bash install.sh install yes yes
```

Useful environment overrides: `KH_CHANNEL=latest`, `KH_FX_GAME_PORT=30120`,
`KH_TXADMIN_PORT=40120`, `KH_LICENSE_KEY=...`, `KH_CUSTOM_BUILD=12000-abc`.

### First TxAdmin login

```bash
journalctl -u fivem -f      # watch for the one-time setup PIN
```
Then open `http://<server-ip>:40120`.

---

## 2. Install the Webpanel (optional)

Clone the repository and run the panel installer:

```bash
git clone https://github.com/Fabio-Kumahost/kumahost-fivem-installer.git
cd kumahost-fivem-installer
sudo bash deploy/install-panel.sh
```

It installs Node.js + nginx, deploys the API/panel to `/opt/kumahost`,
generates `.env` (with a random `JWT_SECRET`), initialises the database,
creates your **admin user**, configures least-privilege `sudoers` rules,
installs the `kumahost-api` systemd service, configures nginx, and optionally
obtains a Let's Encrypt certificate.

Open `http://<domain-or-ip>/` and log in.

### Manual / development run

```bash
cd api
cp .env.example .env       # set a strong JWT_SECRET
npm install
npm run init-db
npm run create-admin -- admin 'your-password'
npm start                  # serves API + panel on :8787
```

---

## Service management

```bash
systemctl status fivem            # game server
systemctl restart fivem
systemctl status kumahost-api     # panel API
journalctl -u kumahost-api -f
```
