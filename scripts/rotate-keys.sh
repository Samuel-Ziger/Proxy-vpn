#!/usr/bin/env bash
# Rotaciona chaves do cliente principal (peer 10.0.0.2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

WG_PORT=51820
DNS_SERVER="10.0.0.1"
CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0"
CLIENT_IP="10.0.0.2/32"
CLIENT_IPV6="fd42:42:42::2/128"
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
NEW_PRESHARED=$(wg genpsk)
echo "$NEW_PRIVATE" > /etc/wireguard/client_private.key
echo "$NEW_PUBLIC" > /etc/wireguard/client_public.key
echo "$NEW_PRESHARED" > /etc/wireguard/client_preshared.key
chmod 600 /etc/wireguard/client_private.key /etc/wireguard/client_public.key /etc/wireguard/client_preshared.key

SERVER_PUBLIC=$(cat /etc/wireguard/server_public.key)

# Remove peer antigo com IP 10.0.0.2
while IFS=$'\t' read -r pubkey allowed; do
  [ -z "$pubkey" ] && continue
  if echo "$allowed" | grep -q "10.0.0.2/32"; then
    wg set wg0 peer "$pubkey" remove
  fi
done < <(wg show wg0 allowed-ips 2>/dev/null || true)

PSK_FILE=$(mktemp)
trap 'rm -f "$PSK_FILE"' EXIT
printf '%s\n' "$NEW_PRESHARED" > "$PSK_FILE"
wg set wg0 peer "$NEW_PUBLIC" preshared-key "$PSK_FILE" allowed-ips "$CLIENT_IP","$CLIENT_IPV6"
wg-quick save wg0 >/dev/null 2>&1 || true

IPV4=$(curl -4 -s --max-time 10 https://ifconfig.me 2>/dev/null || echo "SEU_IP_AQUI")

cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = ${NEW_PRIVATE}
Address = ${CLIENT_IP}, ${CLIENT_IPV6}
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${SERVER_PUBLIC}
PresharedKey = ${NEW_PRESHARED}
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
