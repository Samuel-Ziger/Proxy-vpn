export interface WireGuardStatus {
  connected: boolean;
  tunnelName: string;
}

export interface WireGuardConnectOptions {
  config: string;
  tunnelName?: string;
}

export interface WireGuardPlugin {
  connect(options: WireGuardConnectOptions): Promise<{ connected: boolean }>;
  disconnect(): Promise<{ connected: boolean }>;
  getStatus(): Promise<WireGuardStatus>;
}
