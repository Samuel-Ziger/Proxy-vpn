#!/usr/bin/env bash
###############################################################################
# GhostTunnel — WireGuard VPS Complete Setup
#
# Uso:
#   sudo bash install-vps-complete.sh          # primeira instalação
#   sudo bash install-vps-complete.sh --force  # reinstalar (regenera chaves)
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WG_PORT=51820
CLIENT_IP="10.0.0.2/32"
CLIENT_IPV6="fd42:42:42::2/128"
SERVER_NET="10.0.0.1/24, fd42:42:42::1/64"
DNS_SERVER="10.0.0.1"
CLIENT_ALLOWED_IPS="0.0.0.0/0, ::/0"
NEW_USER="vpnuser"
FORCE=false

for arg in "$@"; do
  if [ "$arg" = "--force" ]; then
    FORCE=true
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}" >&2; }

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Execute como root: sudo bash install-vps-complete.sh"
    exit 1
  fi
}

configure_ssh_hardening() {
  log_info "Configurando SSH (hardening via drop-in)..."
  mkdir -p /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/99-ghosttunnel.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
EOF

  if [ -d /root/.ssh ] && [ -f /root/.ssh/authorized_keys ]; then
    install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "/home/$NEW_USER/.ssh"
    install -m 600 -o "$NEW_USER" -g "$NEW_USER" /root/.ssh/authorized_keys "/home/$NEW_USER/.ssh/authorized_keys"
    log_success "Chaves SSH copiadas para $NEW_USER"
  else
    log_warn "authorized_keys de root não encontrado — configure SSH para $NEW_USER antes de sair"
  fi

  if ! sshd -t; then
    log_warn "Drop-in SSH inválido no OpenSSH desta VPS — tentando configuração mínima..."
    cat > /etc/ssh/sshd_config.d/99-ghosttunnel.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
EOF
    if ! sshd -t; then
      log_warn "SSH hardening ignorado; WireGuard continuará. Ajuste /etc/ssh manualmente depois."
      rm -f /etc/ssh/sshd_config.d/99-ghosttunnel.conf
      return 0
    fi
  fi

  systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || systemctl restart sshd
  log_success "SSH endurecido (root/senha desabilitados)"
}

show_existing_summary() {
  IPV4=$(curl -4 -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "SEU_IP_AQUI")
  echo ""
  ghost_success_vps
  echo ""
  log_warn "WireGuard já instalado. Use --force para reinstalar (invalida clientes)."
  echo "IP público: $IPV4"
  echo "Porta: $WG_PORT"
  echo "Cliente: /root/wg-client.conf"
  echo "Status: sudo wg show"
}

echo ""
ghost_banner_vps
ghost_tunnel_flow
echo ""

check_root

if [ -f /etc/wireguard/wg0.conf ] && [ "$FORCE" = false ]; then
  show_existing_summary
  exit 0
fi

if [ -f /etc/wireguard/wg0.conf ] && [ "$FORCE" = true ]; then
  BACKUP_DIR="/etc/wireguard/backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp -a /etc/wireguard/*.conf /etc/wireguard/*.key "$BACKUP_DIR/" 2>/dev/null || true
  log_warn "Backup anterior em $BACKUP_DIR"
  wg-quick down wg0 2>/dev/null || true
fi

log_info "Passo 1: Atualizando sistema..."
apt update
apt upgrade -y -qq
log_success "Sistema atualizado"

log_info "Passo 2: Criando usuário sudoer..."
if ! id "$NEW_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  log_success "Usuário '$NEW_USER' criado"
else
  log_warn "Usuário '$NEW_USER' já existe"
fi

configure_ssh_hardening

log_info "Passo 3: Instalando WireGuard e dependências..."
apt install -y -qq wireguard wireguard-tools qrencode ufw fail2ban curl unattended-upgrades
log_success "WireGuard instalado"

log_info "Passo 4: Gerando chaves criptográficas..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard
umask 077
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
wg genpsk > /etc/wireguard/client_preshared.key
log_success "Chaves geradas"

SERVER_PRIVATE=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC=$(cat /etc/wireguard/server_public.key)
CLIENT_PRIVATE=$(cat /etc/wireguard/client_private.key)
CLIENT_PUBLIC=$(cat /etc/wireguard/client_public.key)
CLIENT_PRESHARED=$(cat /etc/wireguard/client_preshared.key)

log_info "Passo 5: Detectando interface de rede..."
OUT_IF=$(ip -o route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)
if [ -z "$OUT_IF" ]; then
  OUT_IF=eth0
  log_warn "Interface padrão: $OUT_IF"
else
  log_success "Interface detectada: $OUT_IF"
fi

log_info "Passo 6: Criando /etc/wireguard/wg0.conf..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${SERVER_NET}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE}
PostUp = sysctl -w net.ipv4.ip_forward=1; sysctl -w net.ipv6.conf.all.forwarding=1
PostDown = sysctl -w net.ipv4.ip_forward=1; sysctl -w net.ipv6.conf.all.forwarding=1
SaveConfig = false

[Peer]
PublicKey = ${CLIENT_PUBLIC}
PresharedKey = ${CLIENT_PRESHARED}
AllowedIPs = ${CLIENT_IP}, ${CLIENT_IPV6}
EOF
chmod 600 /etc/wireguard/wg0.conf
log_success "wg0.conf criado"

log_info "Passo 7: Habilitando IP forwarding..."
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
if ! grep -q "^net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf; then
  echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
fi
if ! grep -q "^net.ipv6.conf.default.forwarding=1" /etc/sysctl.conf; then
  echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1
log_success "IP forwarding habilitado"

log_info "Passo 8: Configurando firewall (UFW)..."
ufw default deny incoming >/dev/null 2>&1 || true
ufw default allow outgoing >/dev/null 2>&1 || true
ufw allow OpenSSH >/dev/null 2>&1 || true
ufw allow "${WG_PORT}/udp" >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true
log_success "UFW configurado"

log_info "Passo 9: Configurando fail2ban..."
cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h
EOF
systemctl enable --now fail2ban >/dev/null 2>&1
log_success "Fail2ban configurado"

log_info "Passo 10: Iniciando WireGuard..."
wg-quick up wg0 || { log_error "Falha ao iniciar WireGuard"; exit 1; }
systemctl enable wg-quick@wg0
log_success "WireGuard iniciado"

log_info "Passo 11: Configurando NAT/forward..."
if ! bash "$SCRIPT_DIR/fix-vpn-nat.sh"; then
  log_warn "NAT/forward com aviso — tentando subir WireGuard manualmente..."
  wg-quick down wg0 2>/dev/null || true
  ip link del wg0 2>/dev/null || true
  wg-quick up wg0 || { log_error "Falha ao iniciar WireGuard após NAT"; exit 1; }
fi
log_success "NAT/forward configurado"

log_info "Passo 12: Ativando DNS filtrado local..."
bash "$SCRIPT_DIR/enable-dns-filter.sh" --local
log_success "DNS filtrado local ativo"

log_info "Passo 13: Detectando IP público..."
IPV4=$(curl -4 -s --max-time 10 https://ifconfig.me 2>/dev/null || curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "")
if [ -z "$IPV4" ]; then
  log_warn "IPv4 não detectado automaticamente"
  IPV4="SEU_IP_AQUI"
else
  log_success "IPv4 detectado"
fi

log_info "Passo 14: Gerando wg-client.conf..."
cat > /root/wg-client.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE}
Address = ${CLIENT_IP}, ${CLIENT_IPV6}
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${SERVER_PUBLIC}
PresharedKey = ${CLIENT_PRESHARED}
Endpoint = ${IPV4}:${WG_PORT}
AllowedIPs = ${CLIENT_ALLOWED_IPS}
PersistentKeepalive = 25
EOF
chmod 600 /root/wg-client.conf
log_success "Cliente: /root/wg-client.conf"

log_info "Passo 15: Gerando QR code..."
qrencode -o /root/wg-client.png -s 10 < /root/wg-client.conf 2>/dev/null || true
log_success "QR: /root/wg-client.png"

systemctl enable unattended-upgrades >/dev/null 2>&1 || true

echo ""
ghost_success_vps
echo ""
echo -e "${GREEN}Informações da VPS:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "IP público:            $IPV4"
echo "Porta WireGuard:       $WG_PORT"
echo "Interface:             $OUT_IF"
echo "Usuário sudo:          $NEW_USER"
echo ""
echo -e "${GREEN}Arquivos do cliente:${NC}"
echo "/root/wg-client.conf"
echo "/root/wg-client.png"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "1. Importe wg-client.conf no app GhostTunnel"
echo "2. Apague /root/wg-client.conf após configurar o celular"
echo "3. Ative VPN sempre ativa no Android"
echo ""
echo -e "${BLUE}Monitorar:${NC} sudo wg show"
log_success "Setup concluído!"
