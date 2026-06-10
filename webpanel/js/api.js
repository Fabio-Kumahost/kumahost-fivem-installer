// =============================================================================
// KumaHost FiveM Webpanel — js/api.js
// Thin fetch wrapper: attaches CSRF header, handles JSON + auth errors,
// and exposes typed helper methods for each endpoint.
// =============================================================================

// Read a cookie value by name (used for the double-submit CSRF token).
function getCookie(name) {
  const match = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`));
  return match ? decodeURIComponent(match[1]) : null;
}

// Core request helper. Cookies carry the JWT + CSRF token; same-origin only.
async function request(path, { method = 'GET', body, raw = false } = {}) {
  const headers = {};
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const csrf = getCookie('kh_csrf');
  if (csrf) headers['X-CSRF-Token'] = csrf;

  const res = await fetch(`/api${path}`, {
    method,
    headers,
    credentials: 'same-origin',
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  // Bounce to login on auth failure (except for the login call itself).
  if (res.status === 401 && !path.startsWith('/auth/login')) {
    if (!location.pathname.endsWith('index.html') && location.pathname !== '/') {
      location.href = 'index.html';
    }
    throw new ApiClientError('Sitzung abgelaufen.', 401);
  }

  if (raw) return res;

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new ApiClientError(data.error || `Fehler ${res.status}`, res.status, data.details);
  }
  return data;
}

export class ApiClientError extends Error {
  constructor(message, status, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export const api = {
  // Auth
  login: (username, password) => request('/auth/login', { method: 'POST', body: { username, password } }),
  logout: () => request('/auth/logout', { method: 'POST' }),
  me: () => request('/auth/me'),

  // System
  stats: () => request('/system/stats'),

  // Servers
  servers: () => request('/servers'),
  serverStatus: (id) => request(`/servers/${id}/status`),
  serverLogs: (id, lines = 200) => request(`/servers/${id}/logs?lines=${lines}`),
  serverAction: (id, action) => request(`/servers/${id}/${action}`, { method: 'POST' }),
  serverUpdate: (id) => request(`/servers/${id}/update`, { method: 'POST' }),

  // Backups
  backups: () => request('/backups'),
  createBackup: () => request('/backups', { method: 'POST' }),
  restoreBackup: (filename) => request(`/backups/${encodeURIComponent(filename)}/restore`, { method: 'POST' }),
  downloadBackupUrl: (filename) => `/api/backups/${encodeURIComponent(filename)}/download`,
};
