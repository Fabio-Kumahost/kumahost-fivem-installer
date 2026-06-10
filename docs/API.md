# KumaHost FiveM API — Reference

Base URL: `http://<host>/api` (proxied by nginx to the Node backend on
`127.0.0.1:8787`).

All responses are JSON. Errors use the shape:

```json
{ "error": "Human readable message", "details": [ { "field": "...", "message": "..." } ] }
```

## Authentication

The API issues a **JWT**. Two transport options are supported:

| Mode | How |
|------|-----|
| **Cookie** (panel) | `kh_token` HttpOnly cookie set on login. Mutating requests must also send the `X-CSRF-Token` header matching the `kh_csrf` cookie. |
| **Bearer** (scripts) | Send `Authorization: Bearer <token>`. Not subject to CSRF (no cookie). |

Rate limits: global `300 req / 15 min`; login `10 failed attempts / 15 min`.

---

### `POST /auth/login`
Authenticate and receive a token.

**Body** `{ "username": "admin", "password": "secret" }`

**200** `{ "token": "<jwt>", "user": { "id": 1, "username": "admin", "role": "admin" } }`
**401** invalid credentials · **400** validation error

### `POST /auth/logout`
Clears the auth cookie. **200** `{ "ok": true }`

### `GET /auth/me`
Current user. **200** `{ "user": { "id", "username", "role" } }` · **401** if not authenticated.

---

## System

### `GET /system/health` — *public*
Liveness probe. **200** `{ "status": "ok", "uptime": 1234.5, "ts": "…" }`

### `GET /system/stats` — *auth*
Host metrics.
```json
{
  "cpu": 12,
  "memory": { "total": 0, "used": 0, "free": 0, "percent": 38 },
  "disk":   { "total": 0, "used": 0, "free": 0, "percent": 41 },
  "network": { "rxBytesPerSec": 0, "txBytesPerSec": 0 },
  "uptimeSeconds": 86400, "hostname": "srv1", "loadAverage": [0.1, 0.2, 0.2]
}
```

---

## Servers

### `GET /servers` — *auth*
List managed servers with live `active` flag.

### `POST /servers` — *admin*
Register a new server.
**Body**
```json
{ "name": "main", "serviceName": "fivem-main", "baseDir": "/opt/fivem-main",
  "gamePort": 30120, "txadminPort": 40120, "channel": "recommended" }
```
**201** `{ "id": 2, "name": "main" }` · **409** name/service taken

### `DELETE /servers/:id` — *admin*
Remove a server record. The `default` server cannot be deleted.

### `GET /servers/:id/status` — *auth*
```json
{ "id": 1, "name": "default", "status": "online",
  "installedVersion": "12000-abc", "recommendedVersion": "12001-def",
  "updateAvailable": true, "txadminPort": 40120 }
```

### `GET /servers/:id/logs?lines=200` — *auth*
**200** `{ "logs": "…" }` (max 2000 lines)

### `POST /servers/:id/start` · `/stop` · `/restart` — *auth*
Controls the systemd service. **200** `{ "ok": true, "action": "start", ... }`

### `POST /servers/:id/update` — *auth*
Updates the FiveM artifact (auto-backup + rollback handled by the installer).
**200** `{ "ok": true, "output": "…" }`

---

## Backups

### `GET /backups` — *auth*
```json
{ "backups": [ { "filename": "fivem-backup-20260610-120000.tar.gz",
                 "sizeBytes": 12345, "createdAt": "2026-06-10T12:00:00.000Z" } ] }
```

### `POST /backups` — *auth*
Create a new backup. **201** `{ "ok": true, "output": "…", "backups": [ … ] }`

### `GET /backups/:filename/download` — *auth*
Streams the archive (`Content-Disposition: attachment`).

### `POST /backups/:filename/restore` — *admin*
Restore an archive. **200** `{ "ok": true, "output": "…" }`

---

## Example (Bearer)

```bash
TOKEN=$(curl -s -X POST http://localhost/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"secret"}' | jq -r .token)

curl -s http://localhost/api/servers/1/status -H "Authorization: Bearer $TOKEN" | jq
curl -s -X POST http://localhost/api/servers/1/restart -H "Authorization: Bearer $TOKEN"
```
