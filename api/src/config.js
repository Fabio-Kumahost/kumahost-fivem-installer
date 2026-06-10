// =============================================================================
// KumaHost FiveM API — config.js
// Centralised, validated configuration loaded from the environment.
// =============================================================================
import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Parse a positive integer env var with a fallback default.
const int = (value, fallback) => {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
};

const bool = (value, fallback = false) =>
  value === undefined ? fallback : /^(1|true|yes)$/i.test(value);

const config = {
  env: process.env.NODE_ENV ?? 'production',
  port: int(process.env.PORT, 8787),
  host: process.env.HOST ?? '127.0.0.1',
  corsOrigin: (process.env.CORS_ORIGIN ?? 'http://localhost:8787')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean),

  jwt: {
    secret: process.env.JWT_SECRET ?? '',
    expiresIn: process.env.JWT_EXPIRES_IN ?? '2h',
  },
  bcryptRounds: int(process.env.BCRYPT_ROUNDS, 12),

  dbPath: path.resolve(__dirname, '..', process.env.DB_PATH ?? './data/kumahost.db'),

  installer: {
    path: process.env.INSTALLER_PATH ?? '/opt/kumahost/installer/install.sh',
    privilegePrefix: process.env.PRIVILEGE_PREFIX ?? 'sudo',
  },

  fivem: {
    service: process.env.FIVEM_SERVICE ?? 'fivem',
    base: process.env.FIVEM_BASE ?? '/opt/fivem',
    logFile: process.env.FIVEM_LOG ?? '/var/log/fivem/server.log',
    txadminPort: int(process.env.TXADMIN_PORT, 40120),
  },

  rate: {
    windowMs: int(process.env.RATE_WINDOW_MS, 15 * 60 * 1000),
    max: int(process.env.RATE_MAX, 300),
    authMax: int(process.env.AUTH_RATE_MAX, 10),
  },

  secureCookies: bool(process.env.SECURE_COOKIES, false),
};

// Fail fast on insecure defaults in production.
export function assertConfig() {
  if (!config.jwt.secret || config.jwt.secret.length < 24) {
    throw new Error('JWT_SECRET fehlt oder ist zu kurz (min. 24 Zeichen). Siehe .env.example.');
  }
  if (config.env === 'production' && config.jwt.secret.includes('change-me')) {
    throw new Error('JWT_SECRET wurde nicht aus dem Standardwert geändert.');
  }
}

export default config;
