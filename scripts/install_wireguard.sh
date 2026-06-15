#!/usr/bin/env bash
set -euo pipefail

# Install and configure WireGuard on Debian/Ubuntu
# Generates server and client keys, creates /etc/wireguard/wg0.conf
# and writes a `client.conf` to /root/wg-client.conf plus a QR PNG.

# Usage: run as root (sudo) on the VPS

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo ./install_wireguard.sh" >&2
  exit 1
fi

# Config - adjust if needed
WG_PORT=51820
CLIENT_IP="10.0.0.2/32"
SERVER_NET="10.0.0.1/24"
DNS_SERVER="1.1.1.1"

echo "Updating packages..."
apt update && apt upgrade -y

echo "Installing dependencies..."
apt install -y wireguard qrencode ufw fail2ban

OUT_IF=$(ip -o route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)
if [ -z "$OUT_IF" ]; then
  OUT_IF=eth0
fi

mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

echo "Generating keys..."
umask 077
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key

SERVER_PRIVATE=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC=$(cat /etc/wireguard/server_public.key)
CLIENT_PRIVATE=$(cat /etc/wireguard/client_private.key)
CLIENT_PUBLIC=$(cat /etc/wireguard/client_public.key)

echo "Writing /etc/wireguard/wg0.conf..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${SERVER_NET}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE}
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${OUT_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${OUT_IF} -j MASQUERADE
SaveConfig = true

[Peer]
PublicKey = ${CLIENT_PUBLIC}
AllowedIPs = ${CLIENT_IP}
EOF

chmod 600 /etc/wireguard/wg0.conf

echo "Enabling IP forwarding permanently..."
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p

echo "Configuring UFW..."
ufw default deny incoming
ufw default allow outgoing
# allow SSH (do not lock yourself out)
ufw allow OpenSSH
ufw allow ${WG_PORT}/udp
ufw --force enable

echo "Brute-force protection: enabling fail2ban (default)"
systemctl enable --now fail2ban || true

echo "Bringing up WireGuard interface..."
wg-quick up wg0 || { echo "wg-quick up failed" >&2; exit 1; }
systemctl enable wg-quick@wg0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/fix-vpn-nat.sh"

# Determine public IPv4 endpoint
IPV4=$(curl -4 -s https://ifconfig.me || true)
PUBLIC_ENDPOINT="${IPV4}:${WG_PORT}"

echo "Writing client config to /root/wg-client.conf and generating QR..."
cat > /root/wg-client.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE}
Address = ${CLIENT_IP}
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${SERVER_PUBLIC}
Endpoint = ${PUBLIC_ENDPOINT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 /root/wg-client.conf
qrencode -o /root/wg-client.png -s 6 < /root/wg-client.conf || true

echo "WireGuard installed and started."
echo "Server public key: ${SERVER_PUBLIC}"
echo "Client config: /root/wg-client.conf"
echo "Client QR: /root/wg-client.png (if qrencode available)"

echo "Important: keep the private keys safe. Back up /etc/wireguard/*.key if needed."

echo "Done."
