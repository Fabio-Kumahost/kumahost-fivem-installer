// =============================================================================
// KumaHost FiveM API — middleware/rateLimit.js
// Global and auth-specific rate limiters.
// =============================================================================
import rateLimit from 'express-rate-limit';
import config from '../config.js';

// Applies to the whole API surface.
export const globalLimiter = rateLimit({
  windowMs: config.rate.windowMs,
  max: config.rate.max,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Zu viele Anfragen — bitte später erneut versuchen.' },
});

// Tighter limit for the login endpoint to slow brute-force attempts.
export const authLimiter = rateLimit({
  windowMs: config.rate.windowMs,
  max: config.rate.authMax,
  standardHeaders: true,
  legacyHeaders: false,
  // Count only failed logins toward the limit.
  skipSuccessfulRequests: true,
  message: { error: 'Zu viele Login-Versuche — bitte später erneut versuchen.' },
});
