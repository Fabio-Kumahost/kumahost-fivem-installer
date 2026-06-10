// =============================================================================
// KumaHost FiveM API — middleware/auth.js
// JWT issuing/verification and route guards.
// =============================================================================
import jwt from 'jsonwebtoken';
import config from '../config.js';

export const AUTH_COOKIE = 'kh_token';

// signToken — create a signed JWT for an authenticated user.
export function signToken(user) {
  return jwt.sign(
    { sub: user.id, username: user.username, role: user.role },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn },
  );
}

// Extract a bearer token from the cookie or Authorization header.
function extractToken(req) {
  if (req.cookies?.[AUTH_COOKIE]) return req.cookies[AUTH_COOKIE];
  const header = req.headers.authorization ?? '';
  if (header.startsWith('Bearer ')) return header.slice(7);
  return null;
}

// requireAuth — reject unauthenticated requests, attach req.user otherwise.
export function requireAuth(req, res, next) {
  const token = extractToken(req);
  if (!token) return res.status(401).json({ error: 'Nicht authentifiziert.' });
  try {
    req.user = jwt.verify(token, config.jwt.secret);
    return next();
  } catch {
    return res.status(401).json({ error: 'Ungültiges oder abgelaufenes Token.' });
  }
}

// requireRole — guard a route by role (use after requireAuth).
export function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Keine Berechtigung.' });
    }
    return next();
  };
}
