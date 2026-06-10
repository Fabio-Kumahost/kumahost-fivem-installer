// =============================================================================
// KumaHost FiveM API — middleware/csrf.js
// Stateless CSRF protection via the double-submit cookie pattern.
// A random token is stored in a readable cookie; state-changing requests must
// echo it back in the X-CSRF-Token header. Same-origin policy prevents an
// attacker site from reading the cookie, so it cannot forge the header.
// =============================================================================
import crypto from 'node:crypto';
import config from '../config.js';

export const CSRF_COOKIE = 'kh_csrf';
const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

// issueCsrfToken — ensure every response carries a CSRF cookie.
export function issueCsrfToken(req, res, next) {
  let token = req.cookies?.[CSRF_COOKIE];
  if (!token) {
    token = crypto.randomBytes(32).toString('hex');
    res.cookie(CSRF_COOKIE, token, {
      httpOnly: false, // must be readable by the panel JS to echo it back
      sameSite: 'strict',
      secure: config.secureCookies,
      path: '/',
    });
  }
  res.locals.csrfToken = token;
  next();
}

// verifyCsrf — enforce the header/cookie match on mutating requests.
export function verifyCsrf(req, res, next) {
  if (SAFE_METHODS.has(req.method)) return next();
  // Bearer-token (header) auth without cookies is not CSRF-exploitable.
  const usesCookieAuth = Boolean(req.cookies?.kh_token);
  if (!usesCookieAuth) return next();

  const cookieToken = req.cookies?.[CSRF_COOKIE];
  const headerToken = req.get('X-CSRF-Token');
  if (!cookieToken || !headerToken || cookieToken !== headerToken) {
    return res.status(403).json({ error: 'CSRF-Token fehlt oder ungültig.' });
  }
  return next();
}
