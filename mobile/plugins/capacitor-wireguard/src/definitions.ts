export interface WireGuardStatus {
  connected: boolean;
  tunnelName: string;
}

export interface WireGuardConnectOptions {
  config: string;
  tunnelName?: string;
}

export interface WireGuardConfigResult {
  json: string;
}

export interface WireGuardPlugin {
  connect(options: WireGuardConnectOptions): Promise<{ connected: boolean; tunnelName?: string }>;
  disconnect(): Promise<{ connected: boolean }>;
  getStatus(): Promise<WireGuardStatus>;
  saveConfig(options: { json: string }): Promise<void>;
  loadConfig(): Promise<WireGuardConfigResult>;
  clearConfig(): Promise<void>;
  openVpnSettings(): Promise<void>;
}
