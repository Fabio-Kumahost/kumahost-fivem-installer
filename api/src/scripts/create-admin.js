// =============================================================================
// KumaHost FiveM API — scripts/create-admin.js
// Create or update a panel admin user. Used by the panel installer.
//
// Usage:
//   node src/scripts/create-admin.js <username> <password> [role]
//   ADMIN_USER=admin ADMIN_PASSWORD=secret node src/scripts/create-admin.js
// =============================================================================
import bcrypt from 'bcryptjs';
import db, { migrate } from '../db.js';
import config from '../config.js';
import logger from '../logger.js';

const username = process.argv[2] ?? process.env.ADMIN_USER;
const password = process.argv[3] ?? process.env.ADMIN_PASSWORD;
const role = process.argv[4] ?? process.env.ADMIN_ROLE ?? 'admin';

if (!username || !password) {
  logger.error('Benutzername und Passwort erforderlich.', {
    usage: 'node src/scripts/create-admin.js <username> <password> [role]',
  });
  process.exit(1);
}
if (password.length < 8) {
  logger.error('Passwort muss mindestens 8 Zeichen lang sein.');
  process.exit(1);
}
if (!['admin', 'operator'].includes(role)) {
  logger.error("Rolle muss 'admin' oder 'operator' sein.");
  process.exit(1);
}

migrate();
const hash = await bcrypt.hash(password, config.bcryptRounds);

// Upsert: update the hash if the user exists, otherwise insert.
const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
if (existing) {
  db.prepare('UPDATE users SET password_hash = ?, role = ? WHERE id = ?').run(hash, role, existing.id);
  logger.info('Admin-Benutzer aktualisiert.', { username, role });
} else {
  db.prepare('INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)').run(username, hash, role);
  logger.info('Admin-Benutzer erstellt.', { username, role });
}
process.exit(0);
