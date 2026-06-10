// =============================================================================
// KumaHost FiveM API — services/stats.service.js
// Host metrics (CPU, RAM, disk, network) gathered from /proc and statfs.
// Linux-focused; degrades gracefully on other platforms.
// =============================================================================
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import os from 'node:os';

const readProc = (file) => {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return '';
  }
};

// Snapshot aggregate CPU jiffies from /proc/stat.
function cpuSnapshot() {
  const line = readProc('/proc/stat').split('\n')[0]; // "cpu  user nice system idle ..."
  const parts = line.trim().split(/\s+/).slice(1).map(Number);
  if (parts.length < 4) return null;
  const idle = parts[3] + (parts[4] ?? 0); // idle + iowait
  const total = parts.reduce((a, b) => a + b, 0);
  return { idle, total };
}

// cpuUsage — percentage busy, sampled over `intervalMs`.
export async function cpuUsage(intervalMs = 200) {
  const a = cpuSnapshot();
  if (!a) {
    // Fallback: load average relative to core count.
    const load = os.loadavg()[0];
    return Math.min(100, Math.round((load / os.cpus().length) * 100));
  }
  await new Promise((r) => setTimeout(r, intervalMs));
  const b = cpuSnapshot();
  const totalDiff = b.total - a.total;
  const idleDiff = b.idle - a.idle;
  if (totalDiff <= 0) return 0;
  return Math.round((1 - idleDiff / totalDiff) * 100);
}

// memoryUsage — total/used/free bytes and percentage.
export function memoryUsage() {
  const total = os.totalmem();
  const free = os.freemem();
  const used = total - free;
  return { total, used, free, percent: Math.round((used / total) * 100) };
}

// diskUsage — usage of the filesystem containing `path`.
export async function diskUsage(path = '/') {
  try {
    const s = await fsp.statfs(path);
    const total = s.blocks * s.bsize;
    const free = s.bfree * s.bsize;
    const used = total - free;
    return { total, used, free, percent: total ? Math.round((used / total) * 100) : 0 };
  } catch {
    return { total: 0, used: 0, free: 0, percent: 0 };
  }
}

// Snapshot total rx/tx bytes across non-loopback interfaces.
function netSnapshot() {
  const lines = readProc('/proc/net/dev').split('\n').slice(2);
  let rx = 0;
  let tx = 0;
  for (const line of lines) {
    const [iface, rest] = line.split(':');
    if (!rest || iface.trim() === 'lo') continue;
    const cols = rest.trim().split(/\s+/).map(Number);
    rx += cols[0] || 0;
    tx += cols[8] || 0;
  }
  return { rx, tx, ts: Date.now() };
}

// networkRate — bytes/sec in/out, sampled over `intervalMs`.
export async function networkRate(intervalMs = 500) {
  const a = netSnapshot();
  await new Promise((r) => setTimeout(r, intervalMs));
  const b = netSnapshot();
  const seconds = (b.ts - a.ts) / 1000 || 1;
  return {
    rxBytesPerSec: Math.max(0, Math.round((b.rx - a.rx) / seconds)),
    txBytesPerSec: Math.max(0, Math.round((b.tx - a.tx) / seconds)),
  };
}

// systemSummary — combined snapshot for the dashboard.
export async function systemSummary() {
  const [cpu, disk, net] = await Promise.all([cpuUsage(), diskUsage('/'), networkRate()]);
  return {
    cpu,
    memory: memoryUsage(),
    disk,
    network: net,
    uptimeSeconds: Math.round(os.uptime()),
    hostname: os.hostname(),
    loadAverage: os.loadavg(),
  };
}
