import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';
import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { StatusBar, Style } from '@capacitor/status-bar';
import { WireGuard } from 'capacitor-wireguard';
import {
  buildWireGuardConfig,
  fetchPublicIp,
  parseWireGuardConf,
  validateFields,
} from './config.js';
import {
  hasRequiredFields,
  loadStoredConfig,
  saveStoredConfig,
} from './storage.js';

const TUNNEL_NAME = 'GhostTunnel';
const SESSION_KEY = 'wg-session-start';

let isConnected = false;
let isBusy = false;
let sessionInterval = null;
let statusHideTimer = null;
let cachedPublicIp = null;

document.addEventListener('DOMContentLoaded', async () => {
  await initNativeUi();
  bindEvents();
  await bootstrap();
});

function bindEvents() {
  document.getElementById('saveBtn').addEventListener('click', saveSettings);
  document.getElementById('toggleBtn').addEventListener('click', toggleConnection);
  document.getElementById('settingsToggle').addEventListener('click', toggleSettings);
  document.getElementById('importBtn').addEventListener('click', importConfText);
  document.getElementById('confFile').addEventListener('change', importConfFile);
  document.getElementById('vpnSettingsBtn').addEventListener('click', openVpnSettings);
  document.getElementById('togglePrivateKey').addEventListener('click', togglePrivateKeyVisibility);
  document.getElementById('wizardDismiss').addEventListener('click', dismissWizard);
}

async function bootstrap() {
  const config = await loadStoredConfig();
  if (config) {
    applyFieldsToForm(config);
    dismissWizard();
  } else {
    showWizard();
    openSettings();
  }

  await refreshStatus();

  App.addListener('appStateChange', ({ isActive }) => {
    if (isActive) refreshStatus();
  });

  if (!Capacitor.isNativePlatform()) {
    showStatus('Este app precisa ser instalado como APK no Android.', 'error', false);
  }
}

async function initNativeUi() {
  if (!Capacitor.isNativePlatform()) return;

  try {
    await StatusBar.setBackgroundColor({ color: '#0d0d12' });
    await StatusBar.setStyle({ style: Style.Dark });
  } catch {
    // StatusBar pode não estar disponível em todos os dispositivos
  }
}

function showWizard() {
  document.getElementById('wizardCard')?.classList.remove('hidden');
}

function dismissWizard() {
  document.getElementById('wizardCard')?.classList.add('hidden');
}

function openSettings() {
  document.getElementById('settingsPanel')?.classList.remove('hidden');
}

function toggleSettings() {
  document.getElementById('settingsPanel').classList.toggle('hidden');
}

function togglePrivateKeyVisibility() {
  const input = document.getElementById('privateKey');
  const btn = document.getElementById('togglePrivateKey');
  const masked = !input.classList.contains('masked');
  input.classList.toggle('masked', masked);
  btn.textContent = masked ? 'Mostrar' : 'Ocultar';
  btn.setAttribute('aria-pressed', masked ? 'false' : 'true');
}

async function openVpnSettings() {
  if (!Capacitor.isNativePlatform()) {
    showStatus('Disponível apenas no APK Android.', 'error');
    return;
  }

  try {
    await WireGuard.openVpnSettings();
  } catch (error) {
    showStatus(error?.message || 'Não foi possível abrir configurações VPN.', 'error');
  }
}

async function saveSettings() {
  const fields = getFormFields();
  if (!validateFields(fields, true, showStatus)) return;

  await saveStoredConfig(fields);
  dismissWizard();
  showStatus('Configuração salva com segurança.', 'success');
  await hapticSuccess();
}

async function importConfText() {
  const text = document.getElementById('confImport').value.trim();
  if (!text) {
    showStatus('Cole o conteúdo do wg-client.conf.', 'error');
    return;
  }

  applyImportedConf(text);
}

async function importConfFile(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  try {
    const text = await file.text();
    applyImportedConf(text);
  } catch {
    showStatus('Não foi possível ler o arquivo.', 'error');
  } finally {
    event.target.value = '';
  }
}

async function applyImportedConf(text) {
  const parsed = parseWireGuardConf(text);
  if (!hasRequiredFields(parsed)) {
    showStatus('Arquivo .conf incompleto ou inválido.', 'error');
    return;
  }

  applyFieldsToForm(parsed);
  await saveStoredConfig(parsed);
  dismissWizard();
  showStatus('Configuração importada do wg-client.conf.', 'success');
  await hapticSuccess();
}

function applyFieldsToForm(config) {
  if (config.serverIp) document.getElementById('serverIp').value = config.serverIp;
  if (config.serverPort) document.getElementById('serverPort').value = config.serverPort;
  if (config.privateKey) document.getElementById('privateKey').value = config.privateKey;
  if (config.publicKeyServer) document.getElementById('publicKeyServer').value = config.publicKeyServer;
  if (config.clientAddress) document.getElementById('clientAddress').value = config.clientAddress;
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
  if (!validateFields(fields, true, showStatus)) return;

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
      cachedPublicIp = null;
      await startSession(fields);
      await refreshPublicIp();
    }
    await saveStoredConfig(fields);
    updateUi(fields);
    showStatus('VPN conectada!', 'success');
    await hapticSuccess();
  } catch (error) {
    isConnected = false;
    stopSession();
    updateUi(fields);
    showStatus(error?.message || 'Falha ao conectar.', 'error');
    await hapticError();
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
    cachedPublicIp = null;
    stopSession();
    updateUi(getFormFields());
    showStatus('VPN desconectada.', 'success');
    await hapticSuccess();
  } catch (error) {
    showStatus(error?.message || 'Falha ao desconectar.', 'error');
    await hapticError();
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
      await resumeSession(fields);
      await refreshPublicIp();
    } else {
      cachedPublicIp = null;
      stopSession();
    }
  } catch {
    isConnected = false;
    cachedPublicIp = null;
    stopSession();
  }

  updateUi(fields);
}

async function refreshPublicIp() {
  const ip = await fetchPublicIp();
  if (ip) {
    cachedPublicIp = ip;
    const ipEl = document.getElementById('displayIp');
    if (ipEl) ipEl.textContent = ip;
  }
}

async function startSession(fields) {
  const now = Date.now();
  localStorage.setItem(SESSION_KEY, String(now));
  startSessionTimer(fields);
}

async function resumeSession(fields) {
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

  if (ipEl) {
    ipEl.textContent = cachedPublicIp || 'Verificando...';
  }

  if (serverEl) {
    serverEl.textContent = fields.serverIp
      ? `${fields.serverIp}:${fields.serverPort || '51820'}`
      : '—';
  }
}

function getFormFields() {
  return {
    serverIp: document.getElementById('serverIp').value.trim(),
    serverPort: document.getElementById('serverPort').value.trim(),
    privateKey: document.getElementById('privateKey').value.trim(),
    publicKeyServer: document.getElementById('publicKeyServer').value.trim(),
    clientAddress: document.getElementById('clientAddress')?.value.trim() || '10.0.0.2/32',
  };
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

  statusDot.setAttribute('aria-label', isConnected ? 'Conectado' : 'Desconectado');
  toggleBtn.setAttribute('aria-pressed', isConnected ? 'true' : 'false');
}

function setBusy(busy, label) {
  isBusy = busy;
  if (label && busy) {
    document.getElementById('toggleBtn').textContent = label;
  }
  updateUi();
}

function showStatus(message, type, autoHide = true) {
  const statusElement = document.getElementById('statusMessage');
  statusElement.textContent = message;
  statusElement.className = `status-message ${type}`;
  statusElement.setAttribute('role', 'status');
  statusElement.setAttribute('aria-live', 'polite');

  if (statusHideTimer) {
    clearTimeout(statusHideTimer);
    statusHideTimer = null;
  }

  if (autoHide) {
    statusHideTimer = setTimeout(() => {
      statusElement.className = 'status-message';
      statusHideTimer = null;
    }, 5000);
  }
}

async function hapticSuccess() {
  if (!Capacitor.isNativePlatform()) return;
  try {
    await Haptics.impact({ style: ImpactStyle.Medium });
  } catch {
    // haptics opcional
  }
}

async function hapticError() {
  if (!Capacitor.isNativePlatform()) return;
  try {
    await Haptics.impact({ style: ImpactStyle.Heavy });
  } catch {
    // haptics opcional
  }
}
