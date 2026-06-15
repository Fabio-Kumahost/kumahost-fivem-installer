# Graph Report - .  (2026-06-14)

## Corpus Check
- 52 files · ~109,063 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 302 nodes · 468 edges · 26 communities (19 shown, 7 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.82)
- Token cost: 100,400 input · 11,155 output

## Community Hubs (Navigation)
- [[_COMMUNITY_API Auth & Middleware|API Auth & Middleware]]
- [[_COMMUNITY_API Reference & Docs|API Reference & Docs]]
- [[_COMMUNITY_Node Dependencies|Node Dependencies]]
- [[_COMMUNITY_Web Panel Frontend|Web Panel Frontend]]
- [[_COMMUNITY_Panel Deployment Script|Panel Deployment Script]]
- [[_COMMUNITY_Shell Logging Helpers|Shell Logging Helpers]]
- [[_COMMUNITY_FiveM Service Backend|FiveM Service Backend]]
- [[_COMMUNITY_FiveM Install & Artifacts|FiveM Install & Artifacts]]
- [[_COMMUNITY_Systemd Service Mgmt|Systemd Service Mgmt]]
- [[_COMMUNITY_System Preflight Checks|System Preflight Checks]]
- [[_COMMUNITY_System Metrics Backend|System Metrics Backend]]
- [[_COMMUNITY_Panel Dashboard UI|Panel Dashboard UI]]
- [[_COMMUNITY_Installer Menu Flow|Installer Menu Flow]]
- [[_COMMUNITY_TxAdmin Setup|TxAdmin Setup]]
- [[_COMMUNITY_Login Screen & Branding|Login Screen & Branding]]
- [[_COMMUNITY_Backup & Restore (Shell)|Backup & Restore (Shell)]]
- [[_COMMUNITY_Dependency Installation|Dependency Installation]]
- [[_COMMUNITY_Firewall Configuration|Firewall Configuration]]
- [[_COMMUNITY_Installer Entrypoint|Installer Entrypoint]]
- [[_COMMUNITY_MariaDB Provisioning|MariaDB Provisioning]]
- [[_COMMUNITY_phpMyAdmin Setup|phpMyAdmin Setup]]
- [[_COMMUNITY_Server Removal|Server Removal]]
- [[_COMMUNITY_Server Update|Server Update]]
- [[_COMMUNITY_API Tests|API Tests]]
- [[_COMMUNITY_Uninstall Script|Uninstall Script]]
- [[_COMMUNITY_Update Script|Update Script]]

## God Nodes (most connected - your core abstractions)
1. `$()` - 19 edges
2. `main()` - 15 edges
3. `Installer (Bash CLI)` - 12 edges
4. `KumaHost FiveM API Reference` - 9 edges
5. `_kh_log()` - 8 edges
6. `KumaHost FiveM Installer (Project)` - 8 edges
7. `REST API (Express)` - 7 edges
8. `scripts` - 6 edges
9. `requireAuth()` - 6 edges
10. `systemSummary()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `KumaHost FiveM Installer Changelog v1.0.0` --conceptually_related_to--> `KumaHost FiveM Installer (Project)`  [INFERRED]
  CHANGELOG.md → README.md
- `Dashboard Page (dashboard.html)` --implements--> `Webpanel (KumaHost Dark Dashboard)`  [INFERRED]
  webpanel/dashboard.html → README.md
- `Login Page (index.html)` --implements--> `Webpanel (KumaHost Dark Dashboard)`  [INFERRED]
  webpanel/index.html → README.md
- `nginx Reverse Proxy` --conceptually_related_to--> `REST API (Express)`  [EXTRACTED]
  docs/INSTALL.md → README.md
- `better-sqlite3 Build (SQLite persistence)` --conceptually_related_to--> `REST API (Express)`  [INFERRED]
  docs/TROUBLESHOOTING.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **KumaHost Three-Component Architecture (Installer, Webpanel, API)** — readme_installer, readme_webpanel, readme_rest_api [EXTRACTED 0.95]
- **API Security Stack (JWT, CSRF, Rate Limiting, sudoers)** — api_authentication, api_csrf_protection, api_rate_limiting, readme_security_model [EXTRACTED 0.90]
- **Panel Deployment Flow (installer provisions API, nginx, env, systemd)** — install_panel_installer, install_nginx_proxy, install_env_config, readme_systemd_service [EXTRACTED 0.85]

## Communities (26 total, 7 thin omitted)

### Community 0 - "API Auth & Middleware"
Cohesion: 0.07
Nodes (38): extractToken(), requireAuth(), requireRole(), signToken(), issueCsrfToken(), SAFE_METHODS, verifyCsrf(), ApiError (+30 more)

### Community 1 - "API Reference & Docs"
Cohesion: 0.10
Nodes (37): API Authentication (JWT, Cookie + Bearer), CSRF Double-Submit Protection, Auth Endpoints (/auth/login, /logout, /me), Backups Endpoints (list, create, download, restore), Servers Endpoints (CRUD, status, logs, control), System Endpoints (/system/health, /system/stats), Rate Limiting (global + login), KumaHost FiveM API Reference (+29 more)

### Community 2 - "Node Dependencies"
Cohesion: 0.07
Nodes (27): dependencies, bcryptjs, better-sqlite3, cookie-parser, cors, dotenv, express, express-rate-limit (+19 more)

### Community 3 - "Web Panel Frontend"
Cohesion: 0.18
Nodes (21): api, ApiClientError, getCookie(), request(), btn, form, label, $() (+13 more)

### Community 4 - "Panel Deployment Script"
Cohesion: 0.21
Nodes (17): configure_env(), configure_nginx(), configure_sudoers(), create_admin_user(), create_user(), deploy_files(), init_database(), install_api_dependencies() (+9 more)

### Community 5 - "Shell Logging Helpers"
Cohesion: 0.19
Nodes (11): die(), _kh_log(), log_detail(), log_error(), log_info(), log_ok(), log_step(), log_warn() (+3 more)

### Community 6 - "FiveM Service Backend"
Cohesion: 0.26
Nodes (11): control(), execFileAsync, installedVersion(), INSTALLER_COMMANDS, isActive(), remoteVersions(), runInstaller(), systemctl() (+3 more)

### Community 7 - "FiveM Install & Artifacts"
Cohesion: 0.25
Nodes (7): choose_artifact_url(), ensure_fivem_user(), install_fivem(), resolve_artifact(), show_versions(), validate_archive(), fivem.sh script

### Community 8 - "Systemd Service Mgmt"
Cohesion: 0.29
Nodes (8): diagnose_service(), health_check(), restart_service(), service_action(), start_and_verify(), start_service(), stop_service(), service.sh script

### Community 9 - "System Preflight Checks"
Cohesion: 0.36
Nodes (7): check_arch(), check_disk(), check_internet(), check_memory(), detect_os(), preflight(), checks.sh script

### Community 10 - "System Metrics Backend"
Cohesion: 0.44
Nodes (8): cpuSnapshot(), cpuUsage(), diskUsage(), memoryUsage(), netSnapshot(), networkRate(), readProc(), systemSummary()

### Community 11 - "Panel Dashboard UI"
Cohesion: 0.38
Nodes (7): Backup Management, Console and Logs Viewer, FXServer, KumaHost FiveM Panel Dashboard, Server Resource Metrics, FiveM Server Control Panel, TxAdmin Integration

### Community 12 - "Installer Menu Flow"
Cohesion: 0.48
Nodes (6): advanced_settings(), do_install(), load_config(), main_menu(), save_config(), menu.sh script

### Community 13 - "TxAdmin Setup"
Cohesion: 0.47
Nodes (4): generate_server_cfg(), prepare_server_data(), setup_txadmin(), txadmin.sh script

### Community 14 - "Login Screen & Branding"
Cohesion: 0.50
Nodes (5): User Authentication, Dark Theme UI Design, FiveM Server Management, KumaHost FiveM Panel, KumaHost FiveM Panel Login Screen

### Community 15 - "Backup & Restore (Shell)"
Cohesion: 0.50
Nodes (3): list_backups(), restore_backup(), backup.sh script

### Community 16 - "Dependency Installation"
Cohesion: 0.60
Nodes (4): install_base_dependencies(), install_packages(), _kh_apt_update(), deps.sh script

### Community 17 - "Firewall Configuration"
Cohesion: 0.50
Nodes (3): firewall_check(), open_port(), firewall.sh script

### Community 18 - "Installer Entrypoint"
Cohesion: 0.50
Nodes (3): KH_LOG_FILE, KH_TEMPLATE_DIR, install.sh script

## Knowledge Gaps
- **74 isolated node(s):** `name`, `version`, `description`, `license`, `type` (+69 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `name`, `version`, `description` to the rest of the system?**
  _74 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `API Auth & Middleware` be split into smaller, more focused modules?**
  _Cohesion score 0.0655367231638418 - nodes in this community are weakly interconnected._
- **Should `API Reference & Docs` be split into smaller, more focused modules?**
  _Cohesion score 0.09759759759759759 - nodes in this community are weakly interconnected._
- **Should `Node Dependencies` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._