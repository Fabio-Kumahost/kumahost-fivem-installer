// =============================================================================
// KumaHost FiveM API — middleware/error.js
// Central 404 + error handling. Keeps internal details out of responses.
// =============================================================================
import logger from '../logger.js';

// ApiError — throwable with an explicit HTTP status code.
export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export function notFound(req, res) {
  res.status(404).json({ error: 'Endpunkt nicht gefunden.' });
}

// eslint-disable-next-line no-unused-vars — Express needs the 4-arg signature.
export function errorHandler(err, req, res, _next) {
  const status = err.status ?? 500;
  if (status >= 500) {
    logger.error('Unbehandelter Fehler', { message: err.message, stack: err.stack });
  }
  res.status(status).json({
    error: status >= 500 ? 'Interner Serverfehler.' : err.message,
  });
}

// asyncHandler — wrap async route handlers so rejections reach errorHandler.
export const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
