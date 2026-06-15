import { WebPlugin } from '@capacitor/core';
import type {
  WireGuardConnectOptions,
  WireGuardPlugin,
  WireGuardStatus,
} from './definitions';

const WEB_STORAGE_KEY = 'ghosttunnel-wg-config';

export class WireGuardWeb extends WebPlugin implements WireGuardPlugin {
  async connect(_options: WireGuardConnectOptions): Promise<{ connected: boolean }> {
    throw this.unavailable('WireGuard VPN só funciona no app Android.');
  }

  async disconnect(): Promise<{ connected: boolean }> {
    throw this.unavailable('WireGuard VPN só funciona no app Android.');
  }

  async getStatus(): Promise<WireGuardStatus> {
    return { connected: false, tunnelName: 'GhostTunnel' };
  }

  async saveConfig(options: { json: string }): Promise<void> {
    localStorage.setItem(WEB_STORAGE_KEY, options.json);
  }

  async loadConfig(): Promise<{ json: string }> {
    return { json: localStorage.getItem(WEB_STORAGE_KEY) || '' };
  }

  async clearConfig(): Promise<void> {
    localStorage.removeItem(WEB_STORAGE_KEY);
  }

  async openVpnSettings(): Promise<void> {
    throw this.unavailable('Configurações VPN só no Android.');
  }
}
