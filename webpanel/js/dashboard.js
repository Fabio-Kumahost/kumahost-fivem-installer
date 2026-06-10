// =============================================================================
// KumaHost FiveM Webpanel — js/dashboard.js
// Dashboard controller: live metrics, server controls, logs and backups.
// =============================================================================
import { api, ApiClientError } from './api.js';
import { toast, formatBytes, formatUptime, escapeHtml } from './ui.js';

const $ = (id) => document.getElementById(id);
let serverId = null;
let statsTimer = null;

// ----- Helpers --------------------------------------------------------------
function setBar(barId, valId, percent) {
  const p = Math.max(0, Math.min(100, Math.round(percent)));
  $(barId).style.width = `${p}%`;
  $(valId).textContent = p;
}

function fail(err) {
  const msg = err instanceof ApiClientError ? err.message : 'Unbekannter Fehler.';
  toast(msg, 'err');
}

// ----- Server status --------------------------------------------------------
async function loadStatus() {
  try {
    const s = await api.serverStatus(serverId);
    $('server-name').textContent = s.name === 'default' ? 'FiveM Server' : s.name;
    $('version').textContent = s.installedVersion;

    const online = s.status === 'online';
    const badge = $('status-badge');
    badge.className = `kh-badge kh-badge--${online ? 'online' : 'offline'}`;
    $('status-text').textContent = online ? 'Online' : 'Offline';

    $('update-badge').classList.toggle('kh-hidden', !s.updateAvailable);

    const link = $('txadmin-link');
    link.href = `http://${location.hostname}:${s.txadminPort}`;
  } catch (err) {
    fail(err);
  }
}

// ----- Live host metrics ----------------------------------------------------
async function loadStats() {
  try {
    const s = await api.stats();
    setBar('cpu-bar', 'cpu-val', s.cpu);
    setBar('ram-bar', 'ram-val', s.memory.percent);
    setBar('disk-bar', 'disk-val', s.disk.percent);
    $('ram-detail').textContent = `${formatBytes(s.memory.used)} / ${formatBytes(s.memory.total)}`;
    $('disk-detail').textContent = `${formatBytes(s.disk.used)} / ${formatBytes(s.disk.total)}`;
    $('net-down').textContent = formatBytes(s.network.rxBytesPerSec);
    $('net-up').textContent = formatBytes(s.network.txBytesPerSec);
    $('uptime').textContent = formatUptime(s.uptimeSeconds);
  } catch (err) {
    // Stop polling on auth failure (api.js handles the redirect).
    if (err instanceof ApiClientError && err.status === 401) clearInterval(statsTimer);
  }
}

// ----- Logs -----------------------------------------------------------------
async function loadLogs() {
  try {
    const { logs } = await api.serverLogs(serverId, 300);
    const el = $('console');
    el.textContent = logs || 'Noch keine Log-Ausgabe vorhanden.';
    el.scrollTop = el.scrollHeight;
  } catch (err) {
    fail(err);
  }
}

// ----- Backups --------------------------------------------------------------
async function loadBackups() {
  try {
    const { backups } = await api.backups();
    const list = $('backups-list');
    if (!backups.length) {
      list.innerHTML = '<span class="kh-muted">Noch keine Backups vorhanden.</span>';
      return;
    }
    list.innerHTML = backups
      .map(
        (b) => `
        <div style="display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between;
                    padding:12px 14px;border:1px solid var(--kh-border);border-radius:12px;">
          <div>
            <div style="font-weight:600;">${escapeHtml(b.filename)}</div>
            <div class="kh-muted" style="font-size:.8rem;">${formatBytes(b.sizeBytes)} · ${new Date(b.createdAt).toLocaleString('de-DE')}</div>
          </div>
          <div class="kh-btn-row">
            <a class="kh-btn kh-btn--ghost kh-btn--sm" href="${api.downloadBackupUrl(b.filename)}">⬇ Download</a>
            <button class="kh-btn kh-btn--ghost kh-btn--sm" data-restore="${escapeHtml(b.filename)}">↩ Wiederherstellen</button>
          </div>
        </div>`,
      )
      .join('');

    list.querySelectorAll('[data-restore]').forEach((el) =>
      el.addEventListener('click', () => restoreBackup(el.dataset.restore)),
    );
  } catch (err) {
    fail(err);
  }
}

async function restoreBackup(filename) {
  if (!confirm(`Backup "${filename}" wiederherstellen? Die aktuelle server-data wird ersetzt.`)) return;
  toast('Wiederherstellung gestartet…');
  try {
    await api.restoreBackup(filename);
    toast('Backup wiederhergestellt.');
    loadStatus();
  } catch (err) {
    fail(err);
  }
}

// ----- Actions --------------------------------------------------------------
function bindControls() {
  document.querySelectorAll('[data-action]').forEach((btn) =>
    btn.addEventListener('click', async () => {
      const action = btn.dataset.action;
      btn.disabled = true;
      try {
        await api.serverAction(serverId, action);
        toast(`Aktion „${action}“ ausgeführt.`);
        setTimeout(loadStatus, 1500);
      } catch (err) {
        fail(err);
      } finally {
        btn.disabled = false;
      }
    }),
  );

  $('update-btn').addEventListener('click', async (e) => {
    if (!confirm('FiveM-Artefakt jetzt aktualisieren? Es wird automatisch ein Backup erstellt.')) return;
    e.target.disabled = true;
    toast('Update läuft – das kann einige Minuten dauern…');
    try {
      await api.serverUpdate(serverId);
      toast('Update abgeschlossen.');
      loadStatus();
    } catch (err) {
      fail(err);
    } finally {
      e.target.disabled = false;
    }
  });

  $('create-backup').addEventListener('click', async (e) => {
    e.target.disabled = true;
    toast('Backup wird erstellt…');
    try {
      await api.createBackup();
      toast('Backup erstellt.');
      loadBackups();
    } catch (err) {
      fail(err);
    } finally {
      e.target.disabled = false;
    }
  });

  $('refresh-logs').addEventListener('click', loadLogs);
  $('logout-btn').addEventListener('click', async () => {
    await api.logout().catch(() => {});
    location.href = 'index.html';
  });
}

// ----- Bootstrap ------------------------------------------------------------
async function init() {
  let me;
  try {
    me = await api.me();
  } catch {
    location.href = 'index.html';
    return;
  }
  $('welcome').textContent = `Angemeldet als ${me.user.username}`;

  const { servers } = await api.servers();
  serverId = servers[0]?.id ?? 1;

  bindControls();
  await Promise.all([loadStatus(), loadStats(), loadLogs(), loadBackups()]);

  // Live refresh: metrics every 4s, status + logs every 10s.
  statsTimer = setInterval(loadStats, 4000);
  setInterval(loadStatus, 10000);
  setInterval(loadLogs, 10000);
}

init();
