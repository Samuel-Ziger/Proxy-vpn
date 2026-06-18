#!/usr/bin/env bash
# GhostTunnel - diagnostico nao destrutivo da VPS

set -euo pipefail

WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_DNS="${WG_DNS:-10.0.0.1}"
WG_PORT="${WG_PORT:-51820}"

ok() { printf '[OK] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; }

check_command() {
  command -v "$1" >/dev/null 2>&1
}

check_service() {
  local service="$1"
  if systemctl is-active --quiet "$service"; then
    ok "$service ativo"
  else
    fail "$service inativo"
  fi
}

check_sysctl() {
  local key="$1"
  local expected="$2"
  local current
  current="$(sysctl -n "$key" 2>/dev/null || true)"
  if [ "$current" = "$expected" ]; then
    ok "$key=$expected"
  else
    fail "$key esperado $expected, atual ${current:-indisponivel}"
  fi
}

echo "GhostTunnel VPS healthcheck"
echo "Interface: $WG_INTERFACE"
echo ""

if [ "$(id -u)" -ne 0 ]; then
  warn "Rode como root para ver todos os detalhes: sudo bash healthcheck-vps.sh"
fi

check_command wg || fail "wireguard-tools ausente"
check_command ufw || warn "ufw ausente"
check_command dnsmasq || warn "dnsmasq ausente"

check_service "wg-quick@${WG_INTERFACE}.service"
if check_command dnsmasq; then
  check_service "dnsmasq.service"
fi

if ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
  ok "$WG_INTERFACE existe"
else
  fail "$WG_INTERFACE nao existe"
fi

if ss -lun 2>/dev/null | grep -q ":${WG_PORT}\b"; then
  ok "UDP ${WG_PORT} escutando"
else
  fail "UDP ${WG_PORT} nao parece estar escutando"
fi

check_sysctl net.ipv4.ip_forward 1
check_sysctl net.ipv6.conf.all.forwarding 1

if check_command ufw; then
  ufw status | grep -q "${WG_PORT}/udp" && ok "UFW permite WireGuard UDP ${WG_PORT}" || warn "UFW pode nao permitir UDP ${WG_PORT}"
  ufw status | grep -q "53" && ok "UFW tem regra DNS" || warn "UFW nao mostra regra DNS explicitamente"
fi

if [ -f /etc/dnsmasq.d/10-ghosttunnel.conf ]; then
  ok "dnsmasq GhostTunnel configurado"
else
  warn "dnsmasq GhostTunnel nao configurado"
fi

if [ -s /etc/dnsmasq.d/99-ghosttunnel-blocklist.conf ]; then
  ok "blocklist DNS presente ($(grep -c '^address=/' /etc/dnsmasq.d/99-ghosttunnel-blocklist.conf) regras)"
else
  warn "blocklist DNS ausente ou vazia"
fi

if check_command dig; then
  if dig @"$WG_DNS" doubleclick.net +short +time=2 +tries=1 2>/dev/null | grep -Eq '^(0\.0\.0\.0|::)$'; then
    ok "DNS local bloqueia doubleclick.net"
  else
    warn "DNS local nao confirmou bloqueio de doubleclick.net"
  fi
else
  warn "dig ausente; instale dnsutils para testar DNS"
fi

echo ""
echo "Peers:"
wg show "$WG_INTERFACE" 2>/dev/null || warn "Nao foi possivel ler wg show"
