// =============================================================================
// KumaHost FiveM API — db.js
// SQLite connection (better-sqlite3) with schema bootstrap and helpers.
// =============================================================================
import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config from './config.js';
import logger from './logger.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCHEMA_PATH = path.resolve(__dirname, '..', 'schema.sql');

// Ensure the data directory exists before opening the file.
fs.mkdirSync(path.dirname(config.dbPath), { recursive: true });

const db = new Database(config.dbPath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

// Apply the schema (idempotent — uses IF NOT EXISTS throughout).
export function migrate() {
  const schema = fs.readFileSync(SCHEMA_PATH, 'utf8');
  db.exec(schema);
  // Seed the default server row the installer manages, if absent.
  const exists = db.prepare('SELECT 1 FROM servers WHERE name = ?').get('default');
  if (!exists) {
    db.prepare(
      `INSERT INTO servers (name, service_name, base_dir, game_port, txadmin_port)
       VALUES (?, ?, ?, ?, ?)`,
    ).run('default', config.fivem.service, config.fivem.base, 30120, config.fivem.txadminPort);
    logger.info('Default-Server in DB angelegt', { service: config.fivem.service });
  }
  logger.info('Datenbank-Schema angewendet', { path: config.dbPath });
}

// Record a privileged action in the audit trail (best effort).
export function audit({ userId = null, action, target = null, ip = null }) {
  try {
    db.prepare(
      'INSERT INTO audit_log (user_id, action, target, ip) VALUES (?, ?, ?, ?)',
    ).run(userId, action, target, ip);
  } catch (err) {
    logger.warn('Audit-Log fehlgeschlagen', { error: err.message });
  }
}

export default db;
