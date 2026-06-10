// =============================================================================
// KumaHost FiveM API — services/fivem.service.js
// Controls the FiveM systemd service and drives the installer for
// install/update/backup actions. All commands run via execFile (no shell),
// against a fixed allowlist, to avoid command injection.
// =============================================================================
import { execFile } from 'node:child_process';
import fs from 'node:fs';
import { promisify } from 'node:util';
import config from '../config.js';
import { ApiError } from '../middleware/error.js';

const execFileAsync = promisify(execFile);

// Build [cmd, args] honouring the configured privilege prefix (e.g. sudo).
function withPrivilege(cmd, args) {
  const prefix = config.installer.privilegePrefix?.trim();
  if (prefix && prefix !== 'none') {
    return [prefix, [cmd, ...args]];
  }
  return [cmd, args];
}

// Run an allow-listed systemctl action against a service name.
const SYSTEMCTL_ACTIONS = new Set(['start', 'stop', 'restart', 'status', 'is-active']);

async function systemctl(action, service) {
  if (!SYSTEMCTL_ACTIONS.has(action)) throw new ApiError(400, `Ungültige Aktion: ${action}`);
  // Service name is constrained to safe characters.
  if (!/^[a-zA-Z0-9._-]+$/.test(service)) throw new ApiError(400, 'Ungültiger Service-Name.');
  const [cmd, args] = withPrivilege('systemctl', [action, service]);
  try {
    const { stdout } = await execFileAsync(cmd, args, { timeout: 30_000 });
    return { ok: true, output: stdout.trim() };
  } catch (err) {
    // is-active/status exit non-zero when inactive — that is a valid answer.
    return { ok: false, output: (err.stdout || err.stderr || err.message || '').trim() };
  }
}

// isActive — boolean service liveness.
export async function isActive(service = config.fivem.service) {
  const res = await systemctl('is-active', service);
  return res.output === 'active';
}

// control — start/stop/restart the service (throws on failure).
export async function control(action, service = config.fivem.service) {
  if (!['start', 'stop', 'restart'].includes(action)) {
    throw new ApiError(400, `Nicht unterstützte Aktion: ${action}`);
  }
  const res = await systemctl(action, service);
  if (!res.ok) throw new ApiError(500, `systemctl ${action} fehlgeschlagen: ${res.output}`);
  return { action, service, ...res };
}

// readLogs — last `lines` lines of the FiveM log file.
export function readLogs(lines = 200) {
  try {
    const content = fs.readFileSync(config.fivem.logFile, 'utf8');
    const all = content.split('\n');
    return all.slice(-Math.max(1, Math.min(lines, 2000))).join('\n');
  } catch {
    return '';
  }
}

// installedVersion — build id from the artifact URL the installer recorded.
export function installedVersion(baseDir = config.fivem.base) {
  try {
    const url = fs.readFileSync(`${baseDir}/.artifact-url`, 'utf8').trim();
    const match = url.match(/master\/([^/]+)\/fx\.tar\.xz/);
    return match ? match[1] : 'unbekannt';
  } catch {
    return 'nicht installiert';
  }
}

// remoteVersions — latest/recommended builds advertised by FiveM.
export async function remoteVersions() {
  try {
    const res = await fetch('https://changelogs-live.fivem.net/api/changelog/versions/linux/server', {
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    const data = await res.json();
    return { latest: data.latest, recommended: data.recommended };
  } catch {
    return null;
  }
}

// updateAvailable — compare the recorded download URL against recommended.
export async function updateAvailable(baseDir = config.fivem.base) {
  const remote = await remoteVersions();
  if (!remote) return { available: false, current: installedVersion(baseDir), recommended: null };
  const current = installedVersion(baseDir);
  return {
    available: Boolean(remote.recommended) && current !== remote.recommended && !current.startsWith(remote.recommended),
    current,
    recommended: remote.recommended,
    latest: remote.latest,
  };
}

// Run an allow-listed installer subcommand (install/update/backup/restore/remove).
const INSTALLER_COMMANDS = new Set(['install', 'update', 'backup', 'restore', 'remove']);

export async function runInstaller(command, extraArgs = []) {
  if (!INSTALLER_COMMANDS.has(command)) throw new ApiError(400, `Ungültiger Befehl: ${command}`);
  const safeArgs = extraArgs.filter((a) => /^[a-zA-Z0-9._/-]+$/.test(a));
  const [cmd, args] = withPrivilege('bash', [config.installer.path, command, ...safeArgs]);
  try {
    const { stdout, stderr } = await execFileAsync(cmd, args, {
      timeout: 15 * 60_000, // installs/updates can be slow
      maxBuffer: 8 * 1024 * 1024,
    });
    return { ok: true, output: `${stdout}\n${stderr}`.trim() };
  } catch (err) {
    throw new ApiError(500, `Installer-Befehl '${command}' fehlgeschlagen: ${(err.stderr || err.message).slice(0, 500)}`);
  }
}
