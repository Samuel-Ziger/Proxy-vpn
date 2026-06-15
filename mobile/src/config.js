export const DNS_FILTER = '94.140.14.14, 94.140.15.15';
export const DEFAULT_CLIENT_ADDRESS = '10.0.0.2/32';
export const LEGACY_STORAGE_KEY = 'wg-config';

export function isValidIPv4(ip) {
  const ipv4Pattern = /^(\d{1,3}\.){3}\d{1,3}$/;
  if (!ipv4Pattern.test(ip)) return false;

  return ip.split('.').every((part) => {
    const num = Number(part);
    return num >= 0 && num <= 255;
  });
}

export function isValidHostname(host) {
  if (!host || host.length > 253) return false;
  return /^(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(host);
}

export function isValidEndpointHost(host) {
  return isValidIPv4(host) || isValidHostname(host);
}

export function isValidWgKey(key) {
  return /^[A-Za-z0-9+/]{42,44}={0,2}$/.test(key);
}

export function parseWireGuardConf(text) {
  const result = {
    serverIp: '',
    serverPort: '51820',
    privateKey: '',
    publicKeyServer: '',
    clientAddress: DEFAULT_CLIENT_ADDRESS,
  };

  let section = '';
  for (const rawLine of text.split('\n')) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;

    if (line.startsWith('[') && line.endsWith(']')) {
      section = line;
      continue;
    }

    const eq = line.indexOf('=');
    if (eq === -1) continue;

    const key = line.slice(0, eq).trim();
    const value = line.slice(eq + 1).trim();

    if (section === '[Interface]') {
      if (key === 'PrivateKey') result.privateKey = value;
      if (key === 'Address') result.clientAddress = value.split(',')[0].trim();
    }

    if (section === '[Peer]') {
      if (key === 'PublicKey') result.publicKeyServer = value;
      if (key === 'Endpoint') {
        const lastColon = value.lastIndexOf(':');
        if (lastColon > -1) {
          result.serverIp = value.slice(0, lastColon).replace(/^\[|\]$/g, '');
          result.serverPort = value.slice(lastColon + 1);
        } else {
          result.serverIp = value;
        }
      }
    }
  }

  return result;
}

export function validateFields(fields, showErrors, showStatus) {
  if (!fields.serverIp || !fields.serverPort || !fields.privateKey || !fields.publicKeyServer) {
    if (showErrors) showStatus('Preencha todos os campos da VPS.', 'error');
    return false;
  }

  if (!isValidEndpointHost(fields.serverIp)) {
    if (showErrors) showStatus('IP ou hostname da VPS inválido.', 'error');
    return false;
  }

  if (!isValidWgKey(fields.privateKey)) {
    if (showErrors) showStatus('Chave privada WireGuard inválida.', 'error');
    return false;
  }

  if (!isValidWgKey(fields.publicKeyServer)) {
    if (showErrors) showStatus('Chave pública do servidor inválida.', 'error');
    return false;
  }

  const port = Number(fields.serverPort);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    if (showErrors) showStatus('Porta inválida.', 'error');
    return false;
  }

  return true;
}

export function buildWireGuardConfig(fields) {
  const {
    serverIp,
    serverPort,
    privateKey,
    publicKeyServer,
    clientAddress = DEFAULT_CLIENT_ADDRESS,
  } = fields;

  return `[Interface]
PrivateKey = ${privateKey}
Address = ${clientAddress}
DNS = ${DNS_FILTER}

[Peer]
PublicKey = ${publicKeyServer}
Endpoint = ${serverIp}:${serverPort}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25`;
}

export async function fetchPublicIp() {
  const endpoints = [
    'https://ifconfig.me/ip',
    'https://api.ipify.org?format=text',
  ];

  for (const url of endpoints) {
    try {
      const res = await fetch(url, { cache: 'no-store' });
      if (res.ok) {
        const ip = (await res.text()).trim();
        if (ip) return ip;
      }
    } catch {
      // tenta próximo endpoint
    }
  }

  return null;
}
