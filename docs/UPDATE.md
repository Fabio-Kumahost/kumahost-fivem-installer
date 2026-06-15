# Update Guide

## Update the FiveM server

### Option A — one-liner

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Fabio-Kumahost/kumahost-fivem-installer/main/update.sh)
```

### Option B — interactive menu

Run the installer and choose **[4] Server aktualisieren**.

### Option C — non-interactive

```bash
sudo bash /opt/kumahost/install.sh update
# choose channel ahead of time:
sudo KH_CHANNEL=recommended bash /opt/kumahost/install.sh update
```

### Option D — from the Webpanel

Dashboard → **Update installieren**. A banner appears automatically when a
newer **recommended** build is available.

### What the updater does

1. Resolves the target artifact (recommended/latest/custom).
2. Skips if you are already on the selected build (unless forced).
3. Creates an **automatic backup** of `server-data` (+ DB dump).
4. Stops the service, swaps the artifact **atomically**, and validates the
   download. On failure it **rolls back** to the previous version.
5. Restarts the service and runs a health check.

`server-data`, `server.cfg`, and your database are never touched by an artifact
update — only the FXServer binaries are replaced.

---

## Update the Webpanel / API

```bash
cd kumahost-fivem-installer
git pull
sudo bash deploy/install-panel.sh   # re-syncs files, keeps .env + data
```

Your `.env` and `api/data/` (database) are preserved across re-runs.

---

## Backups

```bash
sudo bash install.sh backup                 # create
sudo bash install.sh restore                # interactive restore
sudo bash install.sh restore /path/to.tar.gz
```

Backups live in `/home/fivem/backups/` as `fivem-backup-YYYYMMDD-HHMMSS.tar.gz`.
