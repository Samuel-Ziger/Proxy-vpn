#!/usr/bin/env bash
# GhostTunnel — corrige "sem internet" (NAT/UFW)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash fix-vpn-nat.sh"
  exit 1
fi

echo ""
ghost_banner_nat
echo ""

OUT_IF=$(ip -o route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)
OUT_IF="${OUT_IF:-eth0}"

echo "Interface de saída detectada: $OUT_IF"

# 1) IP forwarding via UFW
SYSCTL_CONF="/etc/ufw/sysctl.conf"
grep -q '^net.ipv4.ip_forward=1' "$SYSCTL_CONF" 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> "$SYSCTL_CONF"

# 2) Política de forward
UFW_DEFAULT="/etc/default/ufw"
if grep -q '^DEFAULT_FORWARD_POLICY=' "$UFW_DEFAULT"; then
  sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' "$UFW_DEFAULT"
else
  echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' >> "$UFW_DEFAULT"
fi

# 3) Regras NAT e forward no before.rules
BEFORE_RULES="/etc/ufw/before.rules"
MARKER="GHOST-TUNNEL-WIREGUARD"

if grep -qE "GHOST-TUNNEL-WIREGUARD|PROXY-VPN-WIREGUARD" "$BEFORE_RULES"; then
  echo "Regras UFW já existem — pulando"
else
  TMP=$(mktemp)
  awk -v iface="$OUT_IF" -v marker="$MARKER" '
    /^# Don.t delete these required lines/ && !done {
      print "# " marker " - NAT para WireGuard"
      print "*nat"
      print ":POSTROUTING ACCEPT [0:0]"
      print "-A POSTROUTING -o " iface " -j MASQUERADE"
      print "COMMIT"
      print ""
      done=1
    }
    { print }
  ' "$BEFORE_RULES" > "$TMP"

  awk -v marker="$MARKER" '
    /^# allow all on loopback/ && !done {
      print "# " marker " - forward wg0"
      print "-A ufw-before-forward -i wg0 -j ACCEPT"
      print "-A ufw-before-forward -o wg0 -j ACCEPT"
      print ""
      done=1
    }
    { print }
  ' "$TMP" > "${TMP}.2" && mv "${TMP}.2" "$TMP"

  cp "$BEFORE_RULES" "${BEFORE_RULES}.bak.$(date +%s)"
  mv "$TMP" "$BEFORE_RULES"
  echo "Regras UFW adicionadas em $BEFORE_RULES"
fi

# 4) Garantir ip_forward ativo
sysctl -w net.ipv4.ip_forward=1
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

# 5) Recarregar firewall e WireGuard
ufw reload
systemctl restart wg-quick@wg0

echo ""
ghost_success_nat
ghost_tunnel_flow
echo ""
echo "No celular: desconecte e reconecte a VPN."
echo "Teste: https://ifconfig.me (deve mostrar o IP da VPS)"
echo ""
echo "Na VPS, com celular conectado:"
echo "  sudo wg show"
