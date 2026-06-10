// =============================================================================
// KumaHost FiveM API — services/backup.service.js
// Lists backup archives on disk and resolves them for download.
// Creation/restore are delegated to the installer (privileged operations).
// =============================================================================
import fs from 'node:fs';
import path from 'node:path';
import config from '../config.js';
import { ApiError } from '../middleware/error.js';

const backupDir = () => path.join(config.fivem.base, 'backups');
const FILE_RE = /^fivem-backup-[0-9]{8}-[0-9]{6}\.tar\.gz$/;

// listBackups — metadata for all archives, newest first.
export function listBackups() {
  const dir = backupDir();
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => FILE_RE.test(f))
    .map((f) => {
      const stat = fs.statSync(path.join(dir, f));
      return { filename: f, sizeBytes: stat.size, createdAt: stat.mtime.toISOString() };
    })
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

// resolveBackupPath — validate a filename and return its absolute path.
// Rejects anything that is not a well-formed backup name (path traversal safe).
export function resolveBackupPath(filename) {
  if (!FILE_RE.test(filename)) throw new ApiError(400, 'Ungültiger Backup-Dateiname.');
  const full = path.join(backupDir(), filename);
  if (!full.startsWith(backupDir() + path.sep) || !fs.existsSync(full)) {
    throw new ApiError(404, 'Backup nicht gefunden.');
  }
  return full;
}
