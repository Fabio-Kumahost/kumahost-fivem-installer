# Changelog

All notable changes to the **KumaHost FiveM Installer** are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-06-10

### Added — Installer
- One-line installer (`install.sh`) with self-bootstrapping over `curl`.
- Interactive 9-option menu (install, +MariaDB, +phpMyAdmin, update, backup,
  restore, remove, advanced settings, exit).
- Automatic system pre-flight checks (OS, architecture, RAM, disk, network).
- Support for Debian 12/13 and Ubuntu 22.04/24.04.
- Automatic dependency installation via `apt`.
- Automatic firewall detection and rule management (`ufw` / `firewalld`).
- FiveM artifact discovery (latest / recommended / custom build) with download
  validation (size + `xz`/`tar` integrity).
- TxAdmin preparation, starter `server.cfg`, and `systemd` service generation.
- Health checks and failure diagnostics after start.
- Safe artifact updates with automatic pre-update backup and rollback.
- Backup creation/restore (server-data + optional MariaDB dump).
- Non-interactive subcommands (`install`, `update`, `backup`, `restore`,
  `remove`, `start`, `stop`, `restart`, `status`) for automation and the API.
- Optional MariaDB and phpMyAdmin provisioning.
- Standalone `update.sh` and `uninstall.sh` wrappers.

### Added — API
- REST API (Express) for server, backup and system management.
- JWT authentication, bcrypt password hashing, rate limiting, input validation
  (zod), CSRF double-submit protection, secure cookies and Helmet headers.
- SQLite persistence with automatic schema migration and audit logging.
- Privileged actions executed via an `execFile` allowlist + `sudoers` rules.

### Added — Webpanel
- KumaHost-branded dark dashboard (server status, live CPU/RAM/disk/network,
  console/logs, version + update indicator, TxAdmin link).
- Server controls (start/stop/restart/update) and full backup management
  (create/download/restore).

### Added — Deployment & Docs
- `deploy/install-panel.sh` one-shot panel installer (Node.js, nginx, DB,
  admin user, sudoers, systemd, optional Let's Encrypt SSL).
- nginx site + `systemd` unit templates.
- Documentation: install, update, troubleshooting and full API reference.
- Integration test suite for the API.

[1.0.0]: https://github.com/Fabio-Kumahost/kumahost-fivem-installer/releases/tag/v1.0.0
