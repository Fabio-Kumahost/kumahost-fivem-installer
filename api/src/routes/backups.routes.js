// =============================================================================
// KumaHost FiveM API — routes/backups.routes.js
// Backup listing, creation, download and restore.
// =============================================================================
import { Router } from 'express';
import { z } from 'zod';
import { audit } from '../db.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { asyncHandler } from '../middleware/error.js';
import * as backups from '../services/backup.service.js';
import * as fivem from '../services/fivem.service.js';

const router = Router();
router.use(requireAuth);

// GET /api/backups — list available archives.
router.get('/', (req, res) => {
  res.json({ backups: backups.listBackups() });
});

// POST /api/backups — create a new backup via the installer.
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const result = await fivem.runInstaller('backup');
    audit({ userId: req.user.sub, action: 'backup.create', ip: req.ip });
    res.status(201).json({ ok: true, output: result.output, backups: backups.listBackups() });
  }),
);

// GET /api/backups/:filename/download — stream an archive to the client.
router.get(
  '/:filename/download',
  validate(z.object({ filename: z.string().max(128) }), 'params'),
  asyncHandler(async (req, res) => {
    const full = backups.resolveBackupPath(req.params.filename);
    audit({ userId: req.user.sub, action: 'backup.download', target: req.params.filename, ip: req.ip });
    res.download(full, req.params.filename);
  }),
);

// POST /api/backups/:filename/restore — restore a backup (admin only).
router.post(
  '/:filename/restore',
  requireRole('admin'),
  validate(z.object({ filename: z.string().max(128) }), 'params'),
  asyncHandler(async (req, res) => {
    const full = backups.resolveBackupPath(req.params.filename);
    const result = await fivem.runInstaller('restore', [full]);
    audit({ userId: req.user.sub, action: 'backup.restore', target: req.params.filename, ip: req.ip });
    res.json({ ok: true, output: result.output });
  }),
);

export default router;
