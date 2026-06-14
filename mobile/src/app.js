// WireGuard Config Generator App - Mobile Version with Capacitor

import { App as CapApp } from '@capacitor/app';
import { Keyboard } from '@capacitor/keyboard';

let currentConfig = null;
let currentQRCode = null;

// Initialize Capacitor
document.addEventListener('DOMContentLoaded', () => {
  // Hide keyboard on app start
  Keyboard.hide();
  
  // Event Listeners
  document.getElementById('generateBtn').addEventListener('click', generateConfig);
  document.getElementById('connectBtn').addEventListener('click', connectWireGuard);
  document.getElementById('downloadBtn').addEventListener('click', downloadConfig);
  document.getElementById('copyBtn').addEventListener('click', copyToClipboard);
  
  // Load saved config
  loadConfig();
});

// Generate config from form inputs
function generateConfig() {
  const serverIp = document.getElementById('serverIp').value.trim();
  const serverPort = document.getElementById('serverPort').value.trim();
  const privateKey = document.getElementById('privateKey').value.trim();
  const publicKeyServer = document.getElementById('publicKeyServer').value.trim();

  // Validation
  if (!serverIp || !serverPort || !privateKey || !publicKeyServer) {
    showStatus('Por favor, preencha todos os campos', 'error');
    return;
  }

  if (!isValidIPv4(serverIp)) {
    showStatus('IP inválido. Use formato: 192.168.1.1', 'error');
    return;
  }

  if (isNaN(serverPort) || serverPort < 1 || serverPort > 65535) {
    showStatus('Porta inválida. Use um número entre 1 e 65535', 'error');
    return;
  }

  // Generate WireGuard config
  const config = generateWireGuardConfig(serverIp, serverPort, privateKey, publicKeyServer);
  currentConfig = config;

  // Show config sections
  document.getElementById('previewSection').style.display = 'block';
  document.getElementById('qrSection').style.display = 'block';
  document.getElementById('actionSection').style.display = 'block';

  // Update preview
  document.getElementById('configPreview').textContent = config;

  // Generate QR code
  generateQRCode(config);

  // Save config
  saveConfig();

  showStatus('Configuração gerada com sucesso!', 'success');
  
  // Hide keyboard
  Keyboard.hide();
}

// Generate WireGuard config
function generateWireGuardConfig(serverIp, serverPort, privateKey, publicKeyServer) {
  const clientIP = '10.0.0.2/32';
  const dnsServer = '1.1.1.1';

  return `[Interface]
PrivateKey = ${privateKey}
Address = ${clientIP}
DNS = ${dnsServer}

[Peer]
PublicKey = ${publicKeyServer}
Endpoint = ${serverIp}:${serverPort}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25`;
}

// Generate QR Code
function generateQRCode(text) {
  const qrContainer = document.getElementById('qrCode');
  qrContainer.innerHTML = '';

  currentQRCode = new QRCode(qrContainer, {
    text: text,
    width: 200,
    height: 200,
    colorDark: '#000000',
    colorLight: '#ffffff',
    correctLevel: QRCode.CorrectLevel.H
  });
}

// Connect to WireGuard
function connectWireGuard() {
  if (!currentConfig) {
    showStatus('Gere a configuração primeiro', 'error');
    return;
  }

  // Copy to clipboard first
  navigator.clipboard.writeText(currentConfig).then(() => {
    showStatus('✓ Config copiada! Abra o app WireGuard e importe', 'success');
    
    // Try to open WireGuard app via intent/scheme
    setTimeout(() => {
      tryOpenWireGuard();
    }, 500);
  }).catch(() => {
    showStatus('Erro ao copiar. Tente novamente', 'error');
  });
}

// Try to open WireGuard app
function tryOpenWireGuard() {
  if (navigator.userAgent.match(/Android/i)) {
    // Android - try WireGuard app scheme
    const baseUrl = 'com.wireguard.android';
    window.location.href = `intent://import/#Intent;scheme=com.wireguard.android;package=com.wireguard.android;end;`;
  } else if (navigator.userAgent.match(/iPhone|iPad|iPod/i)) {
    // iOS - try WireGuard scheme
    window.location.href = 'wireguard://';
  }
}

// Download config as .conf file
function downloadConfig() {
  if (!currentConfig) {
    showStatus('Gere a configuração primeiro', 'error');
    return;
  }

  const element = document.createElement('a');
  element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(currentConfig));
  element.setAttribute('download', 'wireguard-client.conf');
  element.style.display = 'none';

  document.body.appendChild(element);
  element.click();
  document.body.removeChild(element);

  showStatus('Config baixado como wireguard-client.conf', 'success');
}

// Copy config to clipboard
function copyToClipboard() {
  if (!currentConfig) {
    showStatus('Gere a configuração primeiro', 'error');
    return;
  }

  navigator.clipboard.writeText(currentConfig).then(() => {
    showStatus('✓ Configuração copiada para a área de transferência!', 'success');
  }).catch(() => {
    showStatus('✗ Erro ao copiar. Tente novamente', 'error');
  });
}

// Show status message
function showStatus(message, type) {
  const statusElement = document.getElementById('statusMessage');
  statusElement.textContent = message;
  statusElement.className = `status-message ${type}`;
  
  setTimeout(() => {
    statusElement.className = 'status-message';
  }, 4000);
}

// Validate IPv4
function isValidIPv4(ip) {
  const ipv4Pattern = /^(\d{1,3}\.){3}\d{1,3}$/;
  if (!ipv4Pattern.test(ip)) return false;

  const parts = ip.split('.');
  for (let part of parts) {
    const num = parseInt(part, 10);
    if (num < 0 || num > 255) return false;
  }

  return true;
}

// Save config to localStorage
function saveConfig() {
  const config = {
    serverIp: document.getElementById('serverIp').value,
    serverPort: document.getElementById('serverPort').value,
    privateKey: document.getElementById('privateKey').value,
    publicKeyServer: document.getElementById('publicKeyServer').value
  };
  localStorage.setItem('wg-config', JSON.stringify(config));
}

// Load config from localStorage
function loadConfig() {
  const saved = localStorage.getItem('wg-config');
  if (saved) {
    try {
      const config = JSON.parse(saved);
      if (config.serverIp) document.getElementById('serverIp').value = config.serverIp;
      if (config.serverPort) document.getElementById('serverPort').value = config.serverPort;
      if (config.privateKey) document.getElementById('privateKey').value = config.privateKey;
      if (config.publicKeyServer) document.getElementById('publicKeyServer').value = config.publicKeyServer;
    } catch (e) {
      console.error('Erro ao carregar config salva:', e);
    }
  }
}
