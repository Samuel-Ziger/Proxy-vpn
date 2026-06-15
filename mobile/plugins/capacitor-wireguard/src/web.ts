import { WebPlugin } from '@capacitor/core';
import type {
  WireGuardConnectOptions,
  WireGuardPlugin,
  WireGuardStatus,
} from './definitions';

export class WireGuardWeb extends WebPlugin implements WireGuardPlugin {
  async connect(_options: WireGuardConnectOptions): Promise<{ connected: boolean }> {
    throw this.unavailable('WireGuard VPN só funciona no app Android.');
  }

  async disconnect(): Promise<{ connected: boolean }> {
    throw this.unavailable('WireGuard VPN só funciona no app Android.');
  }

  async getStatus(): Promise<WireGuardStatus> {
    return { connected: false, tunnelName: 'ProxyVPN' };
  }
}
