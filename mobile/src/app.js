import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';
import { WireGuard } from 'capacitor-wireguard';

const TUNNEL_NAME = 'ProxyVPN';
const STORAGE_KEY = 'wg-config';

let isConnected = false;
let isBusy = false;

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('saveBtn').addEventListener('click', saveSettings);
  document.getElementById('toggleBtn').addEventListener('click', toggleConnection);
  document.getElementById('settingsToggle').addEventListener('click', toggleSettings);

  loadSettings();
  refreshStatus();

  App.addListener('appStateChange', ({ isActive }) => {
    if (isActive) refreshStatus();
  });

  if (!Capacitor.isNativePlatform()) {
    showStatus('Este app precisa ser instalado como APK no Android.', 'error', false);
  }
});

function toggleSettings() {
  const panel = document.getElementById('settingsPanel');
  const isHidden = panel.style.display === 'none';
  panel.style.display = isHidden ? 'block' : 'none';
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
  setBusy(true);
  showStatus('Conectando...', 'success');

  try {
    const result = await WireGuard.connect({
      config,
      tunnelName: TUNNEL_NAME,
    });

    isConnected = result.connected;
    saveSettingsQuiet(fields);
    updateUi();
    showStatus('VPN conectada com sucesso!', 'success');
  } catch (error) {
    isConnected = false;
    updateUi();
    showStatus(error?.message || 'Falha ao conectar.', 'error');
  } finally {
    setBusy(false);
  }
}

async function disconnectVpn() {
  setBusy(true);
  showStatus('Desconectando...', 'success');

  try {
    await WireGuard.disconnect();
    isConnected = false;
    updateUi();
    showStatus('VPN desconectada.', 'success');
  } catch (error) {
    showStatus(error?.message || 'Falha ao desconectar.', 'error');
  } finally {
    setBusy(false);
  }
}

async function refreshStatus() {
  if (!Capacitor.isNativePlatform()) {
    updateUi();
    return;
  }

  try {
    const status = await WireGuard.getStatus();
    isConnected = status.connected;
  } catch {
    isConnected = false;
  }

  updateUi();
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
DNS = 1.1.1.1

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

function updateUi() {
  const toggleBtn = document.getElementById('toggleBtn');
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');

  if (isConnected) {
    toggleBtn.textContent = 'Desconectar VPN';
    toggleBtn.className = 'btn btn-danger btn-large';
    statusDot.className = 'status-dot connected';
    statusText.textContent = 'Conectado à VPS';
  } else {
    toggleBtn.textContent = 'Conectar VPN';
    toggleBtn.className = 'btn btn-success btn-large';
    statusDot.className = 'status-dot disconnected';
    statusText.textContent = 'Desconectado';
  }

  toggleBtn.disabled = isBusy;
}

function setBusy(busy) {
  isBusy = busy;
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
