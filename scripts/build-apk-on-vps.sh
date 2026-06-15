#!/usr/bin/env bash
###############################################################################
# Build APK on VPS - Complete Automated Build
# Roda NA VPS para baixar tudo e gerar o APK
#
# Uso:
#   sudo bash /root/build-apk-on-vps.sh
#
# Ou da internet:
#   curl -O https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/build-apk-on-vps.sh
#   sudo bash build-apk-on-vps.sh
###############################################################################

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
BUILD_DIR="/opt/GhostTunnel"
if [ ! -d "$BUILD_DIR/mobile" ]; then
  BUILD_DIR="/opt/Proxy-vpn"
fi
if [ ! -d "$BUILD_DIR/mobile" ]; then
  BUILD_DIR="/opt/wireguard-apk"
fi
REPO_URL="https://github.com/Samuel-Ziger/Proxy-vpn.git"
APK_OUTPUT="${BUILD_DIR}/mobile/android/app/build/outputs/apk/debug"

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
  exit 1
}

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script deve ser executado como root"
    exit 1
  fi
}

###############################################################################
# MAIN
###############################################################################

echo ""
ghost_banner_apk
ghost_spinner_line "Compilando o fantasma no servidor..."
echo ""

check_root

# Step 1: Instalar dependências do sistema
log_info "Passo 1: Instalando dependências do sistema..."
apt update -qq
apt install -y -qq \
  curl \
  wget \
  git \
  unzip \
  openjdk-17-jdk \
  build-essential \
  >/dev/null 2>&1

export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export PATH="$JAVA_HOME/bin:$PATH"

log_success "Dependências instaladas"

# Step 2: Instalar Node.js (se não tem)
log_info "Passo 2: Verificando Node.js..."
if ! command -v node &> /dev/null; then
  log_warn "Node.js não encontrado. Instalando..."
  
  # Instalar Node.js via NodeSource
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
  apt install -y -qq nodejs >/dev/null 2>&1
  log_success "Node.js instalado: $(node --version)"
else
  log_success "Node.js já instalado: $(node --version)"
fi

# Step 3: Instalar Android SDK (verifica se existe)
log_info "Passo 3: Verificando Android SDK..."
if [ -z "${ANDROID_HOME:-}" ] || [ ! -d "$ANDROID_HOME" ]; then
  log_warn "ANDROID_HOME não configurado ou inválido"
  log_info "Instalando Android SDK Essentials..."
  
  # Criar diretório
  ANDROID_HOME="/opt/android-sdk"
  mkdir -p "$ANDROID_HOME"
  
  # Download SDK tools
  cd /tmp
  log_info "  Baixando Android SDK Command-line Tools..."
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-9123335_latest.zip -O cmdline-tools.zip
  
  unzip -q cmdline-tools.zip -d "$ANDROID_HOME/"
  rm cmdline-tools.zip
  
  # Setup SDK
  export PATH="$ANDROID_HOME/cmdline-tools/bin:$PATH"
  export ANDROID_HOME="$ANDROID_HOME"
  
  # Aceitar licenças
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  
  # Instalar componentes essenciais
  log_info "  Instalando componentes do SDK..."
  sdkmanager --install \
    "platforms;android-35" \
    "build-tools;35.0.0" \
    >/dev/null 2>&1 || true
  
  log_success "Android SDK instalado em $ANDROID_HOME"
else
  log_success "Android SDK encontrado: $ANDROID_HOME"
fi

# Exportar variáveis
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export PATH="$ANDROID_HOME/cmdline-tools/bin:$PATH"

# Step 4: Clonar/atualizar repositório
log_info "Passo 4: Preparando código-fonte..."
if [ -d "/opt/GhostTunnel/mobile" ]; then
  BUILD_DIR="/opt/GhostTunnel"
  cd "$BUILD_DIR"
  log_success "Usando repositório local em /opt/GhostTunnel"
elif [ -d "/opt/Proxy-vpn/mobile" ]; then
  BUILD_DIR="/opt/Proxy-vpn"
  cd "$BUILD_DIR"
  log_success "Usando repositório local em /opt/Proxy-vpn"
elif [ -d "$BUILD_DIR" ]; then
  log_info "  Atualizando repo existente..."
  cd "$BUILD_DIR"
  git pull -q origin main || git fetch -q origin main
else
  log_info "  Clonando novo repo..."
  git clone -q "$REPO_URL" "$BUILD_DIR"
  cd "$BUILD_DIR"
fi

log_success "Repositório sincronizado"

# Step 5: Instalar dependências do projeto
log_info "Passo 5: Instalando dependências do projeto (pode levar alguns minutos)..."
cd "$BUILD_DIR/mobile"
npm install --silent >/dev/null 2>&1
log_success "npm packages instalados"

# Step 6: Build web app
log_info "Passo 6: Compilando web app..."
npm run build >/dev/null 2>&1
log_success "Web app compilado"

# Step 7: Adicionar plataforma Android
log_info "Passo 7: Configurando Capacitor Android..."
npx cap add android 2>/dev/null || true
log_success "Plataforma Android configurada"

# Step 8: Sincronizar arquivos
log_info "Passo 8: Sincronizando arquivos para Android..."
npx cap sync android >/dev/null 2>&1
log_success "Arquivos sincronizados"

# Step 9: Build APK
log_info "Passo 9: Compilando APK (pode levar ~10 minutos)..."
log_warn "   Isso pode demorar, aguarde..."
cd "$BUILD_DIR/mobile/android"
chmod +x gradlew
./gradlew assembleDebug

# Verificar se build foi bem-sucedido
if [ -f "$APK_OUTPUT/app-debug.apk" ]; then
  log_success "APK compilado com sucesso!"
else
  log_error "Falha ao compilar APK. Verifique os logs acima."
fi

# Step 10: Copiar APK para local acessível
log_info "Passo 10: Preparando APK para download..."
FINAL_APK="/root/ghost-tunnel.apk"
cp "$APK_OUTPUT/app-debug.apk" "$FINAL_APK"
chmod 644 "$FINAL_APK"
log_success "APK copiado: $FINAL_APK"

# Step 11: Criar servidor HTTP simples (opcional)
log_info "Passo 11: Oferecendo APK via HTTP (opcional)..."
cd /root

cat > /tmp/apk-server.py <<'PYEOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

PORT = 8080
HANDLER = http.server.SimpleHTTPRequestHandler

class MyHandler(HANDLER):
    def do_GET(self):
        if self.path in ('/ghost-tunnel.apk', '/wireguard.apk'):
            self.path = '/ghost-tunnel.apk'
        return super().do_GET()

if __name__ == '__main__':
    os.chdir('/root')
    with socketserver.TCPServer(("", PORT), MyHandler) as httpd:
        print(f"📦 Servidor HTTP iniciado em http://0.0.0.0:{PORT}")
        print(f"📥 Baixe o APK em: http://SEU_IP_VPS:8080/ghost-tunnel.apk")
        print("Pressione Ctrl+C para parar")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServidor parado.")
            sys.exit(0)
PYEOF

chmod +x /tmp/apk-server.py

# Detectar IP da VPS
VPS_IP=$(curl -4 -s https://ifconfig.me 2>/dev/null || echo "SEU_IP_AQUI")

# Summary
echo ""
ghost_success_apk
echo ""

echo -e "${GREEN}📱 APK pronto:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Arquivo:  $FINAL_APK"
ls -lh "$FINAL_APK"
echo ""

echo -e "${GREEN}📥 Formas de baixar:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Via SCP (do seu computador):"
echo "   scp usuario@${VPS_IP}:/root/ghost-tunnel.apk ."
echo ""
echo "2. Via servidor HTTP simples:"
echo "   python3 /tmp/apk-server.py &"
echo "   Depois acesse: http://${VPS_IP}:8080/ghost-tunnel.apk"
echo ""
echo "3. Via SSH + cat:"
echo "   ssh usuario@${VPS_IP} 'cat /root/ghost-tunnel.apk' > ghost-tunnel.apk"
echo ""

echo -e "${BLUE}📝 Próximos passos:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Baixe o APK usando um dos métodos acima"
echo "2. Copie para seu Android (email, USB, etc)"
echo "3. Abra o arquivo e instale"
echo "4. Abra Configuração da VPS e preencha IP/chaves (uma vez)"
echo "5. Toque em 'Conectar VPN' — conexão direta, sem app WireGuard externo"
echo ""

log_success "Build completo!"
