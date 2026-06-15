#!/usr/bin/env bash
# Rotaciona chaves do cliente principal (peer 10.0.0.2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

WG_PORT=51820
DNS_SERVER="94.140.14.14, 94.140.15.15"
CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0"
CLIENT_IP="10.0.0.2/32"
WG_CONF="/etc/wireguard/wg0.conf"
CLIENT_CONF="/root/wg-client.conf"

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash rotate-keys.sh"
  exit 1
fi

if [ ! -f "$WG_CONF" ]; then
  echo "WireGuard não instalado."
  exit 1
fi

BACKUP_DIR="/etc/wireguard/backup-rotate-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -a "$WG_CONF" /etc/wireguard/*.key "$BACKUP_DIR/" 2>/dev/null || true
[ -f "$CLIENT_CONF" ] && cp "$CLIENT_CONF" "$BACKUP_DIR/"

umask 077
NEW_PRIVATE=$(wg genkey)
NEW_PUBLIC=$(echo "$NEW_PRIVATE" | wg pubkey)
echo "$NEW_PRIVATE" > /etc/wireguard/client_private.key
echo "$NEW_PUBLIC" > /etc/wireguard/client_public.key
chmod 600 /etc/wireguard/client_private.key /etc/wireguard/client_public.key

SERVER_PUBLIC=$(cat /etc/wireguard/server_public.key)

# Remove peer antigo com IP 10.0.0.2
while IFS=$'\t' read -r pubkey allowed; do
  [ -z "$pubkey" ] && continue
  if echo "$allowed" | grep -q "10.0.0.2/32"; then
    wg set wg0 peer "$pubkey" remove
  fi
done < <(wg show wg0 allowed-ips 2>/dev/null || true)

wg set wg0 peer "$NEW_PUBLIC" allowed-ips "$CLIENT_IP"

IPV4=$(curl -4 -s --max-time 10 https://ifconfig.me 2>/dev/null || echo "SEU_IP_AQUI")

cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = ${NEW_PRIVATE}
Address = ${CLIENT_IP}
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${SERVER_PUBLIC}
Endpoint = ${IPV4}:${WG_PORT}
AllowedIPs = ${CLIENT_ALLOWED_IPS}
PersistentKeepalive = 25
EOF
chmod 600 "$CLIENT_CONF"
qrencode -o /root/wg-client.png -s 10 < "$CLIENT_CONF" 2>/dev/null || true

echo ""
ghost_success_vps
echo ""
echo "Chaves do cliente rotacionadas."
echo "Backup: $BACKUP_DIR"
echo "Novo config: $CLIENT_CONF"
echo ""
echo "Reimporte wg-client.conf no GhostTunnel e reconecte."
