import { registerPlugin } from '@capacitor/core';
import type { WireGuardPlugin } from './definitions';

const WireGuard = registerPlugin<WireGuardPlugin>('WireGuard', {
  web: () => import('./web').then((m) => new m.WireGuardWeb()),
});

export * from './definitions';
export { WireGuard };
