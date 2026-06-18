export const DNS_FILTER = '10.0.0.1';
export const DEFAULT_CLIENT_ADDRESS = '10.0.0.2/32, fd42:42:42::2/128';
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

export function isValidIPv6(ip) {
  if (!ip || !ip.includes(':')) return false;

  const normalized = ip.replace(/^\[|\]$/g, '').toLowerCase();
  try {
    const parsed = new URL(`http://[${normalized}]`);
    return parsed.hostname.replace(/^\[|\]$/g, '') === normalized;
  } catch {
    return false;
  }
}

export function isValidEndpointHost(host) {
  const normalized = host?.replace(/^\[|\]$/g, '');
  return isValidIPv4(normalized) || isValidIPv6(normalized) || isValidHostname(normalized);
}

export function hasNoLineBreaks(value) {
  return typeof value === 'string' && !/[\r\n]/.test(value);
}

export function isValidWgKey(key) {
  return /^[A-Za-z0-9+/]{42,44}={0,2}$/.test(key);
}

export function isValidCidrAddress(address) {
  const [host, prefix] = address.trim().replace(/^\[|\]$/g, '').split('/');
  if (!host || !prefix) return false;

  const prefixNum = Number(prefix);
  if (!Number.isInteger(prefixNum)) return false;

  if (isValidIPv4(host)) {
    return prefixNum >= 0 && prefixNum <= 32;
  }

  if (isValidIPv6(host)) {
    return prefixNum >= 0 && prefixNum <= 128;
  }

  return false;
}

export function isValidAddressList(value) {
  return hasNoLineBreaks(value) && value.split(',').every((entry) => isValidCidrAddress(entry));
}

export function isValidDnsList(value) {
  return hasNoLineBreaks(value) && value.split(',').every((entry) => {
    const dns = entry.trim().replace(/^\[|\]$/g, '');
    return isValidIPv4(dns) || isValidIPv6(dns) || isValidHostname(dns);
  });
}

export function parseWireGuardConf(text) {
  const result = {
    serverIp: '',
    serverPort: '51820',
    privateKey: '',
    publicKeyServer: '',
    presharedKey: '',
    clientAddress: DEFAULT_CLIENT_ADDRESS,
    dnsServers: DNS_FILTER,
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
      if (key === 'Address') result.clientAddress = value;
      if (key === 'DNS') result.dnsServers = value;
    }

    if (section === '[Peer]') {
      if (key === 'PublicKey') result.publicKeyServer = value;
      if (key === 'PresharedKey') result.presharedKey = value;
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

  if (fields.presharedKey && !isValidWgKey(fields.presharedKey)) {
    if (showErrors) showStatus('PresharedKey WireGuard inválida.', 'error');
    return false;
  }

  const port = Number(fields.serverPort);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    if (showErrors) showStatus('Porta inválida.', 'error');
    return false;
  }

  if (!isValidAddressList(fields.clientAddress || DEFAULT_CLIENT_ADDRESS)) {
    if (showErrors) showStatus('Endereco do cliente WireGuard invalido.', 'error');
    return false;
  }

  if (!isValidDnsList(fields.dnsServers || DNS_FILTER)) {
    if (showErrors) showStatus('DNS do tunel invalido.', 'error');
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
    presharedKey,
    clientAddress = DEFAULT_CLIENT_ADDRESS,
    dnsServers = DNS_FILTER,
  } = fields;

  const presharedLine = presharedKey ? `PresharedKey = ${presharedKey}\n` : '';

  return `[Interface]
PrivateKey = ${privateKey}
Address = ${clientAddress}
DNS = ${dnsServers || DNS_FILTER}

[Peer]
PublicKey = ${publicKeyServer}
Endpoint = ${formatEndpoint(serverIp, serverPort)}
${presharedLine}AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25`;
}

export function formatEndpoint(host, port) {
  const normalized = host.replace(/^\[|\]$/g, '');
  return isValidIPv6(normalized) ? `[${normalized}]:${port}` : `${normalized}:${port}`;
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
