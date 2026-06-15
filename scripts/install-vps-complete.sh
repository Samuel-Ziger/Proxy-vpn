#!/usr/bin/env bash
###############################################################################
# WireGuard VPS Complete Setup Script
# Instala e configura WireGuard VPN na VPS em um comando
#
# Uso:
#   wget -O install-vps.sh https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/install-vps-complete.sh
#   sudo bash install-vps.sh
#
# Ou localmente:
#   sudo bash scripts/install-vps-complete.sh
###############################################################################

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config
WG_PORT=51820
CLIENT_IP="10.0.0.2/32"
SERVER_NET="10.0.0.1/24"
DNS_SERVER="94.140.14.14, 94.140.15.15"
NEW_USER="vpnuser"

###############################################################################
# Funções
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

log_warn() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}✗ $1${NC}" >&2
}

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script deve ser executado como root (sudo)"
    exit 1
  fi
}

###############################################################################
# MAIN
###############################################################################

echo ""
ghost_banner_vps
ghost_tunnel_flow
echo ""

check_root

# Step 1: Atualizar sistema
log_info "Passo 1: Atualizando sistema..."
apt update
apt upgrade -y -qq
log_success "Sistema atualizado"

# Step 2: Criar usuário não-root
log_info "Passo 2: Criando usuário sudoer..."
if ! id "$NEW_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  log_success "Usuário '$NEW_USER' criado"
else
  log_warn "Usuário '$NEW_USER' já existe"
fi

# Step 3: Configurar SSH
log_info "Passo 3: Configurando SSH (hardening)..."
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
log_success "SSH configurado (root desabilit., key-only)"

# Step 4: Instalar WireGuard
log_info "Passo 4: Instalando WireGuard e dependências..."
apt install -y -qq wireguard wireguard-tools qrencode ufw fail2ban curl
log_success "WireGuard instalado"

# Step 5: Gerar chaves
log_info "Passo 5: Gerando chaves criptográficas..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

umask 077
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key

SERVER_PRIVATE=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC=$(cat /etc/wireguard/server_public.key)
CLIENT_PRIVATE=$(cat /etc/wireguard/client_private.key)
CLIENT_PUBLIC=$(cat /etc/wireguard/client_public.key)

log_success "Chaves geradas"

# Step 6: Detectar interface de rede
log_info "Passo 6: Detectando interface de rede..."
OUT_IF=$(ip -o route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -n1)
if [ -z "$OUT_IF" ]; then
  OUT_IF=eth0
  log_warn "Interface detectada como: $OUT_IF (pode estar incorreta)"
else
  log_success "Interface detectada: $OUT_IF"
fi

# Step 7: Criar wg0.conf
log_info "Passo 7: Criando /etc/wireguard/wg0.conf..."
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
log_success "wg0.conf criado"

# Step 8: Habilitar IP forwarding
log_info "Passo 8: Habilitando IP forwarding..."
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1
log_success "IP forwarding habilitado"

# Step 9: Configurar UFW
log_info "Passo 9: Configurando firewall (UFW)..."
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow OpenSSH >/dev/null 2>&1
ufw allow ${WG_PORT}/udp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1
log_success "UFW configurado"

# Step 10: Fail2Ban
log_info "Passo 10: Configurando fail2ban..."
cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF
systemctl enable --now fail2ban >/dev/null 2>&1
log_success "Fail2ban configurado"

# Step 11: Iniciar WireGuard
log_info "Passo 11: Iniciando WireGuard..."
wg-quick up wg0 || { log_error "Falha ao iniciar WireGuard"; exit 1; }
systemctl enable wg-quick@wg0
log_success "WireGuard iniciado"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_info "Configurando NAT/forward para VPN (UFW)..."
bash "$SCRIPT_DIR/fix-vpn-nat.sh"
log_success "NAT/forward VPN configurado"

# Step 12: Obter IP público
log_info "Passo 12: Detectando IP público..."
IPV4=$(curl -4 -s https://ifconfig.me 2>/dev/null || echo "")
if [ -z "$IPV4" ]; then
  log_warn "Não conseguiu detectar IPv4. Use o IP manual."
  IPV4="SEU_IP_AQUI"
else
  log_success "IPv4 detectado: $IPV4"
fi

# Step 13: Gerar arquivo cliente
log_info "Passo 13: Gerando arquivo de cliente..."
cat > /root/wg-client.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE}
Address = ${CLIENT_IP}
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${SERVER_PUBLIC}
Endpoint = ${IPV4}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 /root/wg-client.conf
log_success "Cliente config criado: /root/wg-client.conf"

# Step 14: Gerar QR
log_info "Passo 14: Gerando QR code..."
qrencode -o /root/wg-client.png -s 10 < /root/wg-client.conf 2>/dev/null || true
log_success "QR code gerado: /root/wg-client.png"

# Step 15: Unattended upgrades
log_info "Passo 15: Configurando atualizações automáticas..."
apt install -y -qq unattended-upgrades
systemctl enable unattended-upgrades >/dev/null 2>&1
log_success "Atualizações automáticas habilitadas"

# Summary
echo ""
ghost_success_vps
echo ""

echo -e "${GREEN}Informações da VPS:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "IP Público:            $IPV4"
echo "Porta WireGuard:       $WG_PORT"
echo "Interface de rede:     $OUT_IF"
echo "Usuário não-root:      $NEW_USER"
echo ""

echo -e "${GREEN}Chaves (salvas em /etc/wireguard/):${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Servidor privada:      $(cat /etc/wireguard/server_private.key | cut -c1-16)..."
echo "Servidor pública:      $(cat /etc/wireguard/server_public.key)"
echo "Cliente privada:       $(cat /etc/wireguard/client_private.key | cut -c1-16)..."
echo "Cliente pública:       $(cat /etc/wireguard/client_public.key)"
echo ""

echo -e "${GREEN}Arquivos do cliente:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "/root/wg-client.conf   (copiar para seu dispositivo)"
echo "/root/wg-client.png    (QR code)"
echo ""

echo -e "${YELLOW}Próximos passos:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Baixe /root/wg-client.conf ou gere o APK (build-apk-on-vps.sh)"
echo "2. Instale o GhostTunnel no celular"
echo "3. Configure IP/chaves no app"
echo "4. Toque em Conectar VPN!"
echo ""

echo -e "${BLUE}Monitorar conexão:${NC}"
echo "  sudo wg show"
echo ""

echo -e "${BLUE}Ver logs:${NC}"
echo "  sudo tail -f /var/log/syslog"
echo ""

log_success "Setup concluído! Sua VPS está pronta para usar."
