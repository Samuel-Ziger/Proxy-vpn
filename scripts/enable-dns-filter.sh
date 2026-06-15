#!/usr/bin/env bash
# Atualiza DNS filtrado (AdGuard) em wg-client.conf existente na VPS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

DNS_FILTER="94.140.14.14, 94.140.15.15"
CLIENT_CONF="/root/wg-client.conf"

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash enable-dns-filter.sh"
  exit 1
fi

echo ""
ghost_banner_nat
echo ""
echo "Ativando DNS filtrado (AdGuard): ads, trackers, malware, phishing"
echo ""

if [ -f "$CLIENT_CONF" ]; then
  if grep -q '^DNS = ' "$CLIENT_CONF"; then
    sed -i "s/^DNS = .*/DNS = ${DNS_FILTER}/" "$CLIENT_CONF"
  else
    sed -i "/^\[Interface\]/a DNS = ${DNS_FILTER}" "$CLIENT_CONF"
  fi
  echo "✓ Atualizado: $CLIENT_CONF"
else
  echo "⚠ $CLIENT_CONF não encontrado — configure DNS no app GhostTunnel"
fi

echo ""
echo "No celular: reconecte a VPN para aplicar."
echo "DNS: ${DNS_FILTER}"
echo ""
ghost_success_nat
