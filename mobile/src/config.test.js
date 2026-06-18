import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildWireGuardConfig,
  formatEndpoint,
  isValidEndpointHost,
  parseWireGuardConf,
  validateFields,
} from './config.js';

const PRIVATE_KEY = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
const PUBLIC_KEY = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=';
const PRESHARED_KEY = 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=';

test('parses full WireGuard config with local DNS, IPv6 address and preshared key', () => {
  const parsed = parseWireGuardConf(`[Interface]
PrivateKey = ${PRIVATE_KEY}
Address = 10.0.0.2/32, fd42:42:42::2/128
DNS = 10.0.0.1

[Peer]
PublicKey = ${PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
Endpoint = [2001:db8::10]:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25`);

  assert.equal(parsed.serverIp, '2001:db8::10');
  assert.equal(parsed.serverPort, '51820');
  assert.equal(parsed.privateKey, PRIVATE_KEY);
  assert.equal(parsed.publicKeyServer, PUBLIC_KEY);
  assert.equal(parsed.presharedKey, PRESHARED_KEY);
  assert.equal(parsed.clientAddress, '10.0.0.2/32, fd42:42:42::2/128');
  assert.equal(parsed.dnsServers, '10.0.0.1');
});

test('builds config preserving optional preshared key and IPv6 endpoint brackets', () => {
  const config = buildWireGuardConfig({
    serverIp: '2001:db8::10',
    serverPort: '51820',
    privateKey: PRIVATE_KEY,
    publicKeyServer: PUBLIC_KEY,
    presharedKey: PRESHARED_KEY,
    clientAddress: '10.0.0.2/32, fd42:42:42::2/128',
    dnsServers: '10.0.0.1',
  });

  assert.match(config, /Endpoint = \[2001:db8::10\]:51820/);
  assert.match(config, new RegExp(`PresharedKey = ${PRESHARED_KEY}`));
  assert.match(config, /DNS = 10\.0\.0\.1/);
});

test('validates IPv4, IPv6 and hostname endpoints', () => {
  assert.equal(isValidEndpointHost('203.0.113.10'), true);
  assert.equal(isValidEndpointHost('vpn.example.com'), true);
  assert.equal(isValidEndpointHost('2001:db8::10'), true);
  assert.equal(formatEndpoint('2001:db8::10', '51820'), '[2001:db8::10]:51820');
});

test('rejects malformed preshared key', () => {
  const errors = [];
  const valid = validateFields(
    {
      serverIp: '203.0.113.10',
      serverPort: '51820',
      privateKey: PRIVATE_KEY,
      publicKeyServer: PUBLIC_KEY,
      presharedKey: 'bad',
    },
    true,
    (message) => errors.push(message),
  );

  assert.equal(valid, false);
  assert.equal(errors.length, 1);
});

test('rejects newline injection in generated config fields', () => {
  const errors = [];
  const valid = validateFields(
    {
      serverIp: '203.0.113.10',
      serverPort: '51820',
      privateKey: PRIVATE_KEY,
      publicKeyServer: PUBLIC_KEY,
      clientAddress: '10.0.0.2/32, fd42:42:42::2/128',
      dnsServers: '10.0.0.1\nPostUp = bad',
    },
    true,
    (message) => errors.push(message),
  );

  assert.equal(valid, false);
  assert.equal(errors.length, 1);
});
