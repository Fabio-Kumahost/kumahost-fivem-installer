// =============================================================================
// KumaHost FiveM API — scripts/init-db.js
// Applies the schema and seeds the default server. Safe to run repeatedly.
// =============================================================================
import { migrate } from '../db.js';
import logger from '../logger.js';

migrate();
logger.info('Datenbank initialisiert.');
process.exit(0);
