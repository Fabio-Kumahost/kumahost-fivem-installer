// =============================================================================
// KumaHost FiveM API — routes/auth.routes.js
// Login, logout and current-user endpoints.
// =============================================================================
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import db, { audit } from '../db.js';
import config from '../config.js';
import { signToken, requireAuth, AUTH_COOKIE } from '../middleware/auth.js';
import { authLimiter } from '../middleware/rateLimit.js';
import { validate } from '../middleware/validate.js';
import { asyncHandler } from '../middleware/error.js';

const router = Router();

const credentialsSchema = z.object({
  username: z.string().min(3).max(64),
  password: z.string().min(1).max(256),
});

// Cookie options shared by login/logout.
const cookieOptions = {
  httpOnly: true,
  sameSite: 'strict',
  secure: config.secureCookies,
  path: '/',
  maxAge: 2 * 60 * 60 * 1000, // 2h, matches JWT default
};

// POST /api/auth/login — verify credentials, issue a JWT cookie.
router.post(
  '/login',
  authLimiter,
  validate(credentialsSchema),
  asyncHandler(async (req, res) => {
    const { username, password } = req.body;
    const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);

    // Always run a hash comparison to keep timing uniform for unknown users.
    const hash = user?.password_hash ?? '$2a$12$invalidinvalidinvalidinvalidinvalidinvalidinv';
    const ok = await bcrypt.compare(password, hash);

    if (!user || !ok) {
      audit({ action: 'login.failed', target: username, ip: req.ip });
      return res.status(401).json({ error: 'Ungültige Anmeldedaten.' });
    }

    db.prepare("UPDATE users SET last_login = datetime('now') WHERE id = ?").run(user.id);
    audit({ userId: user.id, action: 'login.success', ip: req.ip });

    const token = signToken(user);
    res.cookie(AUTH_COOKIE, token, cookieOptions);
    return res.json({
      token, // also returned for header-based (Bearer) clients
      user: { id: user.id, username: user.username, role: user.role },
    });
  }),
);

// POST /api/auth/logout — clear the auth cookie.
router.post('/logout', (req, res) => {
  res.clearCookie(AUTH_COOKIE, { ...cookieOptions, maxAge: undefined });
  res.json({ ok: true });
});

// GET /api/auth/me — current authenticated user.
router.get('/me', requireAuth, (req, res) => {
  res.json({ user: { id: req.user.sub, username: req.user.username, role: req.user.role } });
});

export default router;
