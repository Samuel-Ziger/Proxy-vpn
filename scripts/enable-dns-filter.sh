#!/usr/bin/env bash
# GhostTunnel - ativa DNS filtrado local para clientes WireGuard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

LOCAL_DNS="10.0.0.1"
PUBLIC_DNS="94.140.14.14, 94.140.15.15"
CLIENT_CONF="/root/wg-client.conf"
MODE="local"

for arg in "$@"; do
  case "$arg" in
    --public)
      MODE="public"
      ;;
    --local)
      MODE="local"
      ;;
    *)
      echo "Uso: sudo bash enable-dns-filter.sh [--local|--public]" >&2
      exit 1
      ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash enable-dns-filter.sh"
  exit 1
fi

update_client_dns() {
  local dns_value="$1"

  if [ -f "$CLIENT_CONF" ]; then
    if grep -q '^DNS = ' "$CLIENT_CONF"; then
      sed -i "s/^DNS = .*/DNS = ${dns_value}/" "$CLIENT_CONF"
    else
      sed -i "/^\[Interface\]/a DNS = ${dns_value}" "$CLIENT_CONF"
    fi

    if grep -q '^AllowedIPs = ' "$CLIENT_CONF" && ! grep -q '::/0' "$CLIENT_CONF"; then
      sed -i 's/^AllowedIPs = .*/AllowedIPs = 0.0.0.0\/0, ::\/0/' "$CLIENT_CONF"
    fi

    chmod 600 "$CLIENT_CONF"
    echo "Atualizado: $CLIENT_CONF"
  else
    echo "Aviso: $CLIENT_CONF nao encontrado. O proximo config gerado ja deve usar DNS correto."
  fi
}

install_local_dns_filter() {
  echo "Instalando dnsmasq e filtro DNS local em ${LOCAL_DNS}..."
  apt update
  apt install -y dnsmasq curl

  cat > /etc/dnsmasq.d/10-ghosttunnel.conf <<EOF
# GhostTunnel local DNS filter
interface=wg0
listen-address=${LOCAL_DNS}
bind-dynamic
domain-needed
bogus-priv
no-resolv
server=94.140.14.14
server=94.140.15.15
cache-size=10000
EOF

  if command -v ufw >/dev/null 2>&1; then
    ufw allow in on wg0 to "${LOCAL_DNS}" port 53 proto udp >/dev/null 2>&1 || true
    ufw allow in on wg0 to "${LOCAL_DNS}" port 53 proto tcp >/dev/null 2>&1 || true
  fi

  systemctl enable dnsmasq >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/update-dns-blocklist.sh"
}

echo ""
ghost_banner_nat
echo ""

if [ "$MODE" = "public" ]; then
  echo "Ativando DNS publico filtrado AdGuard: ${PUBLIC_DNS}"
  update_client_dns "$PUBLIC_DNS"
else
  install_local_dns_filter
  update_client_dns "$LOCAL_DNS"
fi

echo ""
echo "No celular: reimporte o wg-client.conf se ele mudou, depois reconecte a VPN."
echo "DNS ativo: $([ "$MODE" = "public" ] && echo "$PUBLIC_DNS" || echo "$LOCAL_DNS")"
echo ""
ghost_success_nat
