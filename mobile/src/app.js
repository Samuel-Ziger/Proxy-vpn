import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';
import { StatusBar, Style } from '@capacitor/status-bar';
import { WireGuard } from 'capacitor-wireguard';

const TUNNEL_NAME = 'GhostTunnel';
const STORAGE_KEY = 'wg-config';
const SESSION_KEY = 'wg-session-start';

// AdGuard DNS — bloqueia ads, trackers, malware e phishing
const DNS_FILTER = '94.140.14.14, 94.140.15.15';
const DNS_LABEL = 'AdGuard (ads + trackers + malware)';

let isConnected = false;
let isBusy = false;
let sessionInterval = null;

document.addEventListener('DOMContentLoaded', async () => {
  await initNativeUi();

  document.getElementById('saveBtn').addEventListener('click', saveSettings);
  document.getElementById('toggleBtn').addEventListener('click', toggleConnection);
  document.getElementById('settingsToggle').addEventListener('click', toggleSettings);

  loadSettings();
  await refreshStatus();

  App.addListener('appStateChange', ({ isActive }) => {
    if (isActive) refreshStatus();
  });

  if (!Capacitor.isNativePlatform()) {
    showStatus('Este app precisa ser instalado como APK no Android.', 'error', false);
  }
});

async function initNativeUi() {
  if (!Capacitor.isNativePlatform()) return;

  try {
    await StatusBar.setBackgroundColor({ color: '#0d0d12' });
    await StatusBar.setStyle({ style: Style.Dark });
  } catch {
    // StatusBar pode não estar disponível em todos os dispositivos
  }
}

function toggleSettings() {
  const panel = document.getElementById('settingsPanel');
  panel.classList.toggle('hidden');
}

function saveSettings() {
  const fields = getFormFields();
  if (!validateFields(fields, true)) return;

  localStorage.setItem(STORAGE_KEY, JSON.stringify(fields));
  showStatus('Configuração salva.', 'success');
}

async function toggleConnection() {
  if (isBusy) return;

  if (!Capacitor.isNativePlatform()) {
    showStatus('VPN nativa disponível apenas no APK Android.', 'error');
    return;
  }

  if (isConnected) {
    await disconnectVpn();
  } else {
    await connectVpn();
  }
}

async function connectVpn() {
  const fields = getFormFields();
  if (!validateFields(fields, true)) return;

  const config = buildWireGuardConfig(fields);
  setBusy(true, 'Conectando...');
  showStatus('Estabelecendo túnel...', 'success');

  try {
    const result = await WireGuard.connect({
      config,
      tunnelName: TUNNEL_NAME,
    });

    isConnected = result.connected;
    if (isConnected) {
      startSession(fields);
    }
    saveSettingsQuiet(fields);
    updateUi(fields);
    showStatus('VPN conectada!', 'success');
  } catch (error) {
    isConnected = false;
    stopSession();
    updateUi(fields);
    showStatus(error?.message || 'Falha ao conectar.', 'error');
  } finally {
    setBusy(false);
  }
}

async function disconnectVpn() {
  setBusy(true, 'Desconectando...');
  showStatus('Encerrando túnel...', 'success');

  try {
    await WireGuard.disconnect();
    isConnected = false;
    stopSession();
    updateUi(getFormFields());
    showStatus('VPN desconectada.', 'success');
  } catch (error) {
    showStatus(error?.message || 'Falha ao desconectar.', 'error');
  } finally {
    setBusy(false);
  }
}

async function refreshStatus() {
  const fields = getFormFields();

  if (!Capacitor.isNativePlatform()) {
    updateUi(fields);
    return;
  }

  try {
    const status = await WireGuard.getStatus();
    isConnected = status.connected;
    if (isConnected) {
      resumeSession(fields);
    } else {
      stopSession();
    }
  } catch {
    isConnected = false;
    stopSession();
  }

  updateUi(fields);
}

function startSession(fields) {
  const now = Date.now();
  localStorage.setItem(SESSION_KEY, String(now));
  startSessionTimer(fields);
}

function resumeSession(fields) {
  if (!localStorage.getItem(SESSION_KEY)) {
    localStorage.setItem(SESSION_KEY, String(Date.now()));
  }
  startSessionTimer(fields);
}

function stopSession() {
  localStorage.removeItem(SESSION_KEY);
  if (sessionInterval) {
    clearInterval(sessionInterval);
    sessionInterval = null;
  }
}

function startSessionTimer(fields) {
  if (sessionInterval) clearInterval(sessionInterval);

  const tick = () => {
    const start = Number(localStorage.getItem(SESSION_KEY));
    if (!start) return;
    const elapsed = Math.max(0, Date.now() - start);
    const el = document.getElementById('sessionTimer');
    if (el) el.textContent = formatDuration(elapsed);
    updateConnectedInfo(fields);
  };

  tick();
  sessionInterval = setInterval(tick, 1000);
}

function formatDuration(ms) {
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  return [h, m, s].map((n) => String(n).padStart(2, '0')).join(':');
}

function updateConnectedInfo(fields) {
  const ipEl = document.getElementById('displayIp');
  const serverEl = document.getElementById('displayServer');
  if (ipEl) ipEl.textContent = fields.serverIp || '—';
  if (serverEl) serverEl.textContent = fields.serverIp
    ? `${fields.serverIp}:${fields.serverPort || '51820'}`
    : '—';
}

function getFormFields() {
  return {
    serverIp: document.getElementById('serverIp').value.trim(),
    serverPort: document.getElementById('serverPort').value.trim(),
    privateKey: document.getElementById('privateKey').value.trim(),
    publicKeyServer: document.getElementById('publicKeyServer').value.trim(),
  };
}

function validateFields(fields, showErrors = false) {
  if (!fields.serverIp || !fields.serverPort || !fields.privateKey || !fields.publicKeyServer) {
    if (showErrors) showStatus('Preencha todos os campos da VPS.', 'error');
    return false;
  }

  if (!isValidIPv4(fields.serverIp)) {
    if (showErrors) showStatus('IP da VPS inválido.', 'error');
    return false;
  }

  const port = Number(fields.serverPort);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    if (showErrors) showStatus('Porta inválida.', 'error');
    return false;
  }

  return true;
}

function buildWireGuardConfig({ serverIp, serverPort, privateKey, publicKeyServer }) {
  return `[Interface]
PrivateKey = ${privateKey}
Address = 10.0.0.2/32
DNS = ${DNS_FILTER}

[Peer]
PublicKey = ${publicKeyServer}
Endpoint = ${serverIp}:${serverPort}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25`;
}

function loadSettings() {
  const saved = localStorage.getItem(STORAGE_KEY);
  if (!saved) return;

  try {
    const config = JSON.parse(saved);
    if (config.serverIp) document.getElementById('serverIp').value = config.serverIp;
    if (config.serverPort) document.getElementById('serverPort').value = config.serverPort;
    if (config.privateKey) document.getElementById('privateKey').value = config.privateKey;
    if (config.publicKeyServer) document.getElementById('publicKeyServer').value = config.publicKeyServer;
  } catch (error) {
    console.error('Erro ao carregar configuração:', error);
  }
}

function saveSettingsQuiet(fields) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(fields));
}

function updateUi(fields = getFormFields()) {
  const toggleBtn = document.getElementById('toggleBtn');
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');
  const connectedPanel = document.getElementById('connectedPanel');

  toggleBtn.classList.remove('btn-success', 'btn-danger', 'connecting');

  if (isBusy) {
    toggleBtn.classList.add('connecting');
    toggleBtn.textContent = isConnected ? 'Desconectando...' : 'Conectando...';
    toggleBtn.disabled = true;
  } else if (isConnected) {
    toggleBtn.classList.add('btn-danger');
    toggleBtn.textContent = 'Desconectar VPN';
    toggleBtn.disabled = false;
    statusDot.className = 'status-dot connected';
    statusText.textContent = 'Conectado à VPS';
    connectedPanel.classList.remove('hidden');
    updateConnectedInfo(fields);
  } else {
    toggleBtn.classList.add('btn-success');
    toggleBtn.textContent = 'Conectar VPN';
    toggleBtn.disabled = false;
    statusDot.className = 'status-dot disconnected';
    statusText.textContent = 'Desconectado';
    connectedPanel.classList.add('hidden');
  }
}

function setBusy(busy, label) {
  isBusy = busy;
  if (label && busy) {
    const toggleBtn = document.getElementById('toggleBtn');
    toggleBtn.textContent = label;
  }
  updateUi();
}

function showStatus(message, type, autoHide = true) {
  const statusElement = document.getElementById('statusMessage');
  statusElement.textContent = message;
  statusElement.className = `status-message ${type}`;

  if (autoHide) {
    setTimeout(() => {
      statusElement.className = 'status-message';
    }, 5000);
  }
}

function isValidIPv4(ip) {
  const ipv4Pattern = /^(\d{1,3}\.){3}\d{1,3}$/;
  if (!ipv4Pattern.test(ip)) return false;

  return ip.split('.').every((part) => {
    const num = Number(part);
    return num >= 0 && num <= 255;
  });
}
