// =============================================================================
// KumaHost FiveM API — routes/servers.routes.js
// Server lifecycle + control: create, delete, start/stop/restart, status,
// logs, install and update.
// =============================================================================
import { Router } from 'express';
import { z } from 'zod';
import db, { audit } from '../db.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { asyncHandler, ApiError } from '../middleware/error.js';
import * as fivem from '../services/fivem.service.js';

const router = Router();
router.use(requireAuth);

const getServer = (id) => db.prepare('SELECT * FROM servers WHERE id = ?').get(id);
const idParam = z.object({ id: z.coerce.number().int().positive() });
// Includes `action` so validate() does not strip it from req.params (zod
// objects drop unknown keys) — and validates the allowed actions in one place.
const actionParam = z.object({
  id: z.coerce.number().int().positive(),
  action: z.enum(['start', 'stop', 'restart']),
});

const createSchema = z.object({
  name: z.string().min(2).max(48).regex(/^[a-zA-Z0-9_-]+$/, 'Nur a-z, 0-9, _ und -'),
  serviceName: z.string().min(2).max(48).regex(/^[a-zA-Z0-9._-]+$/),
  baseDir: z.string().min(1).max(256),
  gamePort: z.number().int().min(1).max(65535).default(30120),
  txadminPort: z.number().int().min(1).max(65535).default(40120),
  channel: z.enum(['recommended', 'latest', 'custom']).default('recommended'),
});

// GET /api/servers — list all managed servers with live status.
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const servers = db.prepare('SELECT * FROM servers ORDER BY id').all();
    const withStatus = await Promise.all(
      servers.map(async (s) => ({
        ...s,
        active: await fivem.isActive(s.service_name),
      })),
    );
    res.json({ servers: withStatus });
  }),
);

// GET /api/servers/:id/status — detailed status incl. version + update info.
router.get(
  '/:id/status',
  validate(idParam, 'params'),
  asyncHandler(async (req, res) => {
    const server = getServer(req.params.id);
    if (!server) throw new ApiError(404, 'Server nicht gefunden.');
    const [active, update] = await Promise.all([
      fivem.isActive(server.service_name),
      fivem.updateAvailable(server.base_dir),
    ]);
    res.json({
      id: server.id,
      name: server.name,
      status: active ? 'online' : 'offline',
      installedVersion: update.current,
      recommendedVersion: update.recommended,
      updateAvailable: update.available,
      txadminPort: server.txadmin_port,
    });
  }),
);

// GET /api/servers/:id/logs?lines=200 — recent server log output.
router.get(
  '/:id/logs',
  validate(idParam, 'params'),
  asyncHandler(async (req, res) => {
    const server = getServer(req.params.id);
    if (!server) throw new ApiError(404, 'Server nicht gefunden.');
    const lines = Math.min(Number.parseInt(req.query.lines, 10) || 200, 2000);
    res.json({ logs: fivem.readLogs(lines) });
  }),
);

// POST /api/servers/:id/update — update the FiveM artifact.
// Registered BEFORE /:id/:action so the literal "update" segment is not
// captured by the generic action route.
router.post(
  '/:id/update',
  validate(idParam, 'params'),
  asyncHandler(async (req, res) => {
    const server = getServer(req.params.id);
    if (!server) throw new ApiError(404, 'Server nicht gefunden.');
    const result = await fivem.runInstaller('update');
    audit({ userId: req.user.sub, action: 'server.update', target: server.name, ip: req.ip });
    res.json({ ok: true, output: result.output });
  }),
);

// POST /api/servers/:id/:action — start | stop | restart.
router.post(
  '/:id/:action',
  validate(actionParam, 'params'),
  asyncHandler(async (req, res) => {
    const { id, action } = req.params;
    const server = getServer(id);
    if (!server) throw new ApiError(404, 'Server nicht gefunden.');
    const result = await fivem.control(action, server.service_name);
    audit({ userId: req.user.sub, action: `server.${action}`, target: server.name, ip: req.ip });
    res.json({ ok: true, ...result });
  }),
);

// POST /api/servers — register + install a new server (admin only).
router.post(
  '/',
  requireRole('admin'),
  validate(createSchema),
  asyncHandler(async (req, res) => {
    const { name, serviceName, baseDir, gamePort, txadminPort, channel } = req.body;
    const exists = db.prepare('SELECT 1 FROM servers WHERE name = ? OR service_name = ?').get(name, serviceName);
    if (exists) throw new ApiError(409, 'Name oder Service bereits vergeben.');

    const info = db
      .prepare(
        `INSERT INTO servers (name, service_name, base_dir, game_port, txadmin_port, channel)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(name, serviceName, baseDir, gamePort, txadminPort, channel);
    audit({ userId: req.user.sub, action: 'server.create', target: name, ip: req.ip });
    res.status(201).json({ id: info.lastInsertRowid, name });
  }),
);

// DELETE /api/servers/:id — remove a server record (admin only).
router.delete(
  '/:id',
  requireRole('admin'),
  validate(idParam, 'params'),
  asyncHandler(async (req, res) => {
    const server = getServer(req.params.id);
    if (!server) throw new ApiError(404, 'Server nicht gefunden.');
    if (server.name === 'default') throw new ApiError(400, 'Standard-Server kann nicht gelöscht werden.');
    db.prepare('DELETE FROM servers WHERE id = ?').run(server.id);
    audit({ userId: req.user.sub, action: 'server.delete', target: server.name, ip: req.ip });
    res.json({ ok: true });
  }),
);

export default router;
