-- =============================================================================
-- KumaHost FiveM API — database schema (SQLite)
-- Applied automatically on startup; safe to run repeatedly.
-- =============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- Panel users (admins/operators).
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT    NOT NULL UNIQUE,
  password_hash TEXT    NOT NULL,
  role          TEXT    NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'operator')),
  created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
  last_login    TEXT
);

-- Managed FiveM servers. The installer currently provisions one ("default"),
-- but the model supports multiple service-backed instances.
CREATE TABLE IF NOT EXISTS servers (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT    NOT NULL UNIQUE,
  service_name  TEXT    NOT NULL UNIQUE,
  base_dir      TEXT    NOT NULL,
  game_port     INTEGER NOT NULL DEFAULT 30120,
  txadmin_port  INTEGER NOT NULL DEFAULT 40120,
  channel       TEXT    NOT NULL DEFAULT 'recommended' CHECK (channel IN ('recommended', 'latest', 'custom')),
  created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- Backup catalogue (file metadata; archives live on disk).
CREATE TABLE IF NOT EXISTS backups (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  server_id   INTEGER NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  filename    TEXT    NOT NULL,
  size_bytes  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- Append-only audit trail of privileged actions.
CREATE TABLE IF NOT EXISTS audit_log (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER REFERENCES users(id) ON DELETE SET NULL,
  action     TEXT    NOT NULL,
  target     TEXT,
  ip         TEXT,
  created_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_backups_server ON backups(server_id);
CREATE INDEX IF NOT EXISTS idx_audit_created  ON audit_log(created_at);
