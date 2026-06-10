// =============================================================================
// KumaHost FiveM Webpanel — js/ui.js
// Shared UI helpers: toasts, byte/uptime formatting.
// =============================================================================

// toast — transient notification in the bottom-right corner.
export function toast(message, type = 'ok', timeout = 3800) {
  let wrap = document.querySelector('.kh-toast-wrap');
  if (!wrap) {
    wrap = document.createElement('div');
    wrap.className = 'kh-toast-wrap';
    document.body.appendChild(wrap);
  }
  const el = document.createElement('div');
  el.className = `kh-toast kh-toast--${type === 'err' ? 'err' : 'ok'}`;
  el.textContent = message;
  wrap.appendChild(el);
  setTimeout(() => {
    el.style.opacity = '0';
    setTimeout(() => el.remove(), 300);
  }, timeout);
}

// formatBytes — human-readable size (binary units).
export function formatBytes(bytes) {
  if (!bytes || bytes < 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / 1024 ** i).toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

// formatUptime — seconds → "Xd Yh Zm".
export function formatUptime(seconds) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return [d && `${d}d`, h && `${h}h`, `${m}m`].filter(Boolean).join(' ');
}

// escapeHtml — neutralise user/log content before inserting into the DOM.
export function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]),
  );
}
