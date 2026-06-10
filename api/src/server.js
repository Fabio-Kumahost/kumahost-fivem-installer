// =============================================================================
// KumaHost FiveM API — server.js
// Express application factory and HTTP bootstrap.
// =============================================================================
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import config, { assertConfig } from './config.js';
import logger from './logger.js';
import { migrate } from './db.js';
import { globalLimiter } from './middleware/rateLimit.js';
import { issueCsrfToken, verifyCsrf } from './middleware/csrf.js';
import { notFound, errorHandler } from './middleware/error.js';

import authRoutes from './routes/auth.routes.js';
import serverRoutes from './routes/servers.routes.js';
import backupRoutes from './routes/backups.routes.js';
import systemRoutes from './routes/system.routes.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PANEL_DIR = path.resolve(__dirname, '..', '..', 'webpanel');

// createApp — assemble the middleware stack and routes (no listener).
export function createApp() {
  const app = express();

  // Behind nginx we trust the first proxy hop for correct client IPs.
  app.set('trust proxy', 1);

  // Security headers. CSP is relaxed enough for the self-hosted panel which
  // loads Google Fonts; tighten further if fonts are self-hosted.
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
          fontSrc: ["'self'", 'https://fonts.gstatic.com'],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", 'data:'],
          connectSrc: ["'self'"],
        },
      },
      crossOriginEmbedderPolicy: false,
    }),
  );

  app.use(
    cors({
      origin: config.corsOrigin,
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '256kb' }));
  app.use(cookieParser());
  app.use(issueCsrfToken);
  app.use('/api', globalLimiter);
  app.use('/api', verifyCsrf);

  // REST API.
  app.use('/api/auth', authRoutes);
  app.use('/api/servers', serverRoutes);
  app.use('/api/backups', backupRoutes);
  app.use('/api/system', systemRoutes);

  // Serve the static webpanel (optional; nginx usually does this in prod).
  app.use(express.static(PANEL_DIR));

  // 404 + error handlers last.
  app.use('/api', notFound);
  app.use(errorHandler);

  return app;
}

// Start the server when executed directly (not when imported by tests).
const isMain = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (isMain) {
  assertConfig();
  migrate();
  const app = createApp();
  app.listen(config.port, config.host, () => {
    logger.info('KumaHost FiveM API gestartet', {
      url: `http://${config.host}:${config.port}`,
      env: config.env,
    });
  });
}

export default createApp;
