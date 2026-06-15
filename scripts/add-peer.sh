#!/usr/bin/env bash
# Adiciona um novo peer WireGuard (segundo dispositivo, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

WG_PORT=51820
DNS_SERVER="94.140.14.14, 94.140.15.15"
CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0"

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash add-peer.sh [nome]"
  exit 1
fi

if ! wg show wg0 &>/dev/null; then
  echo "WireGuard não está ativo. Rode install-vps-complete.sh primeiro."
  exit 1
fi

PEER_NAME="${1:-device}"
SERVER_PUBLIC=$(cat /etc/wireguard/server_public.key)

NEXT_HOST=2
while wg show wg0 allowed-ips | grep -q "10.0.0.${NEXT_HOST}/32"; do
  NEXT_HOST=$((NEXT_HOST + 1))
  if [ "$NEXT_HOST" -gt 254 ]; then
    echo "Sem IPs livres na subnet 10.0.0.0/24"
    exit 1
  fi
done

CLIENT_IP="10.0.0.${NEXT_HOST}/32"
PEER_DIR="/root/peers"
mkdir -p "$PEER_DIR"
umask 077

CLIENT_PRIVATE=$(wg genkey)
CLIENT_PUBLIC=$(echo "$CLIENT_PRIVATE" | wg pubkey)

wg set wg0 peer "$CLIENT_PUBLIC" allowed-ips "$CLIENT_IP"

IPV4=$(curl -4 -s --max-time 10 https://ifconfig.me 2>/dev/null || echo "SEU_IP_AQUI")

CLIENT_FILE="${PEER_DIR}/wg-client-${PEER_NAME}.conf"
cat > "$CLIENT_FILE" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE}
Address = ${CLIENT_IP}
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${SERVER_PUBLIC}
Endpoint = ${IPV4}:${WG_PORT}
AllowedIPs = ${CLIENT_ALLOWED_IPS}
PersistentKeepalive = 25
EOF
chmod 600 "$CLIENT_FILE"
qrencode -o "${PEER_DIR}/wg-client-${PEER_NAME}.png" -s 8 < "$CLIENT_FILE" 2>/dev/null || true

echo ""
ghost_success_vps
echo ""
echo "Peer adicionado: $PEER_NAME"
echo "IP do cliente: $CLIENT_IP"
echo "Config: $CLIENT_FILE"
echo "QR: ${PEER_DIR}/wg-client-${PEER_NAME}.png"
echo ""
echo "Importe o arquivo no GhostTunnel."
