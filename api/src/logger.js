// =============================================================================
// KumaHost FiveM API — logger.js
// Minimal, dependency-free structured logger (stdout JSON + human prefix).
// =============================================================================
const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };
const threshold = LEVELS[process.env.LOG_LEVEL ?? 'info'] ?? LEVELS.info;

function emit(level, message, meta) {
  if (LEVELS[level] > threshold) return;
  const entry = {
    ts: new Date().toISOString(),
    level,
    message,
    ...(meta && typeof meta === 'object' ? meta : {}),
  };
  const stream = level === 'error' || level === 'warn' ? process.stderr : process.stdout;
  stream.write(`${JSON.stringify(entry)}\n`);
}

const logger = {
  error: (msg, meta) => emit('error', msg, meta),
  warn: (msg, meta) => emit('warn', msg, meta),
  info: (msg, meta) => emit('info', msg, meta),
  debug: (msg, meta) => emit('debug', msg, meta),
};

export default logger;
