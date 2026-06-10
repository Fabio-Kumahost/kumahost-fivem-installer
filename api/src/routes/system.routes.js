// =============================================================================
// KumaHost FiveM API — routes/system.routes.js
// Host metrics for the dashboard and an unauthenticated health probe.
// =============================================================================
import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/error.js';
import { systemSummary } from '../services/stats.service.js';

const router = Router();

// GET /api/system/health — liveness probe (no auth) for load balancers.
router.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime(), ts: new Date().toISOString() });
});

// GET /api/system/stats — CPU/RAM/disk/network snapshot (auth required).
router.get(
  '/stats',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json(await systemSummary());
  }),
);

export default router;
