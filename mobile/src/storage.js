import { Capacitor } from '@capacitor/core';
import { WireGuard } from 'capacitor-wireguard';
import { LEGACY_STORAGE_KEY } from './config.js';

export async function loadStoredConfig() {
  if (Capacitor.isNativePlatform()) {
    try {
      const { json } = await WireGuard.loadConfig();
      if (json) {
        return JSON.parse(json);
      }

      const legacy = localStorage.getItem(LEGACY_STORAGE_KEY);
      if (legacy) {
        const parsed = JSON.parse(legacy);
        await saveStoredConfig(parsed);
        localStorage.removeItem(LEGACY_STORAGE_KEY);
        return parsed;
      }
    } catch (error) {
      console.error('Erro ao carregar configuração segura:', error);
    }
    return null;
  }

  const saved = localStorage.getItem(LEGACY_STORAGE_KEY);
  if (!saved) return null;

  try {
    return JSON.parse(saved);
  } catch {
    return null;
  }
}

export async function saveStoredConfig(fields) {
  const json = JSON.stringify(fields);

  if (Capacitor.isNativePlatform()) {
    await WireGuard.saveConfig({ json });
    localStorage.removeItem(LEGACY_STORAGE_KEY);
    return;
  }

  localStorage.setItem(LEGACY_STORAGE_KEY, json);
}

export async function clearStoredConfig() {
  if (Capacitor.isNativePlatform()) {
    await WireGuard.clearConfig();
  }
  localStorage.removeItem(LEGACY_STORAGE_KEY);
}

export function hasRequiredFields(fields) {
  return Boolean(
    fields?.serverIp &&
      fields?.serverPort &&
      fields?.privateKey &&
      fields?.publicKeyServer,
  );
}
