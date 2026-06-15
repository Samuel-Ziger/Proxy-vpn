#!/usr/bin/env bash
###############################################################################
# GhostTunnel — Build APK + GitHub Release
#
# Uso:
#   sudo bash build-and-push-apk.sh
#
# Pré-requisitos:
#   - GitHub CLI instalado: sudo apt install gh -y
#   - Autenticado no GitHub: gh auth login
#   - Token com permissões de releases
###############################################################################

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###############################################################################
# Funções
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
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

check_gh_cli() {
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI não encontrado. Instale com: sudo apt install gh -y"
    exit 1
  fi
}

check_git() {
  if ! command -v git &> /dev/null; then
    log_error "Git não encontrado. Instale com: sudo apt install git -y"
    exit 1
  fi
}

###############################################################################
# MAIN
###############################################################################

echo ""
ghost_banner_release
echo ""

check_root
check_gh_cli
check_git

# Step 1: Gerar APK
log_info "Passo 1: Gerando APK..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -x "$SCRIPT_DIR/build-apk-on-vps.sh" ]; then
  bash "$SCRIPT_DIR/build-apk-on-vps.sh"
elif [ -x "/root/build-apk-on-vps.sh" ]; then
  bash /root/build-apk-on-vps.sh
else
  log_error "build-apk-on-vps.sh não encontrado em $SCRIPT_DIR nem em /root"
fi

APK_FILE="/root/ghost-tunnel.apk"
if [ ! -f "$APK_FILE" ]; then
  log_error "APK não foi gerado em $APK_FILE"
  exit 1
fi

APK_SIZE=$(ls -lh "$APK_FILE" | awk '{print $5}')
log_success "APK gerado: $APK_SIZE"

# Step 2: Clonar/sincronizar repositório
log_info "Passo 2: Sincronizando repositório GitHub..."
REPO_DIR="/tmp/GhostTunnel-release"
if [ -d "$REPO_DIR" ]; then
  cd "$REPO_DIR"
  git pull -q origin main 2>/dev/null || git fetch -q origin main
else
  git clone -q https://github.com/Samuel-Ziger/Proxy-vpn.git "$REPO_DIR"
  cd "$REPO_DIR"
fi

log_success "Repositório sincronizado"

# Step 3: Copiar APK para repo
log_info "Passo 3: Copiando APK para repositório..."
mkdir -p "$REPO_DIR/releases"
cp "$APK_FILE" "$REPO_DIR/releases/ghost-tunnel.apk"
chmod 644 "$REPO_DIR/releases/ghost-tunnel.apk"

log_success "APK copiado"

# Step 4: Gerar versão e data
log_info "Passo 4: Gerando informações de release..."
VERSION="v$(date +%Y.%m.%d)"
BUILD_DATE=$(date '+%d/%m/%Y %H:%M:%S')
BUILD_HASH=$(git -C "$REPO_DIR" rev-parse --short HEAD)

RELEASE_NOTES="
## GhostTunnel ${VERSION#v}

**Build:**
- Data: $BUILD_DATE
- Commit: $BUILD_HASH
- Tamanho: $APK_SIZE

**Instalação:**
1. Baixe \`ghost-tunnel.apk\`
2. Instale no Android
3. Configure IP/chaves da VPS
4. Toque em Conectar VPN

**Recursos:**
- Cliente WireGuard nativo
- Conexão com um toque
- Chaves apenas no dispositivo
"

log_success "Versão: $VERSION"

# Step 5: Fazer commit do APK no repo
log_info "Passo 5: Commitando APK..."
cd "$REPO_DIR"
git add "releases/ghost-tunnel.apk" || true
git config user.name "GhostTunnel Builder" || true
git config user.email "builder@ghosttunnel.local" || true

if git diff --cached --quiet; then
  log_warn "Nenhuma mudança no APK (pode ser idêntico)"
else
  git commit -m "Auto-build: Update APK for $VERSION [build $BUILD_HASH]" || true
fi

log_success "Commit feito"

# Step 6: Fazer push
log_info "Passo 6: Fazendo push para GitHub..."
git push -q origin main 2>/dev/null || log_warn "Push falhou (pode estar atualizado)"
log_success "Push para main concluído"

# Step 7: Criar GitHub Release
log_info "Passo 7: Criando GitHub Release..."
cd "$REPO_DIR"

# Verificar se release já existe
if gh release view "$VERSION" &>/dev/null 2>&1; then
  log_warn "Release $VERSION já existe. Atualizando..."
  gh release delete "$VERSION" -y 2>/dev/null || true
fi

# Criar nova release
gh release create "$VERSION" \
  "releases/ghost-tunnel.apk" \
  --repo Samuel-Ziger/Proxy-vpn \
  --title "GhostTunnel $VERSION" \
  --notes "$RELEASE_NOTES" \
  --latest \
  2>/dev/null || log_error "Falha ao criar release"

log_success "Release $VERSION criada no GitHub"

# Step 8: Gerar link de download
log_info "Passo 8: Gerando informações de download..."
DOWNLOAD_URL="https://github.com/Samuel-Ziger/Proxy-vpn/releases/download/$VERSION/ghost-tunnel.apk"
QR_URL="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$(echo -n "$DOWNLOAD_URL" | sed 's/ /%20/g' | sed 's/&/%26/g' | sed 's/=/%3D/g')"

# Summary
echo ""
ghost_success_apk
echo ""

echo -e "${GREEN}📱 Release criado:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Versão:      $VERSION"
echo "Release URL: https://github.com/Samuel-Ziger/Proxy-vpn/releases/tag/$VERSION"
echo "Download:    $DOWNLOAD_URL"
echo ""

echo -e "${GREEN}📥 Download no celular:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Abra no navegador: $DOWNLOAD_URL"
echo ""
echo "2. Ou escanear QR code:"
echo "   $QR_URL"
echo ""
echo "3. Ou acesse releases:"
echo "   https://github.com/Samuel-Ziger/Proxy-vpn/releases"
echo ""

echo -e "${BLUE}📊 Informações:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tamanho:     $APK_SIZE"
echo "Commit:      $BUILD_HASH"
echo "Data:        $BUILD_DATE"
echo ""

log_success "Tudo pronto! Você pode baixar no celular agora."
