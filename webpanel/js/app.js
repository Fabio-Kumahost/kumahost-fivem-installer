// =============================================================================
// KumaHost FiveM Webpanel — js/app.js
// Login page controller.
// =============================================================================
import { api, ApiClientError } from './api.js';
import { toast } from './ui.js';

const form = document.getElementById('login-form');
const btn = document.getElementById('login-btn');
const label = document.getElementById('login-label');

// If already authenticated, skip straight to the dashboard.
api.me().then(() => { location.href = 'dashboard.html'; }).catch(() => { /* not logged in */ });

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const username = document.getElementById('username').value.trim();
  const password = document.getElementById('password').value;

  btn.disabled = true;
  label.innerHTML = '<span class="kh-spinner"></span>';
  try {
    await api.login(username, password);
    location.href = 'dashboard.html';
  } catch (err) {
    const message = err instanceof ApiClientError ? err.message : 'Anmeldung fehlgeschlagen.';
    toast(message, 'err');
    btn.disabled = false;
    label.textContent = 'Anmelden';
  }
});
