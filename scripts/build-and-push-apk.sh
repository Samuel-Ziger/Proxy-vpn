#!/usr/bin/env bash
###############################################################################
# GhostTunnel — Build APK + GitHub Release (sem commit de APK no Git)
#
# Uso:
#   sudo bash build-and-push-apk.sh
#
# Pré-requisitos:
#   gh auth login
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=ghost-art.sh
source "$SCRIPT_DIR/ghost-art.sh"

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
  log_error "Execute como root"
fi

command -v gh >/dev/null 2>&1 || log_error "Instale GitHub CLI: sudo apt install gh -y"
gh auth status >/dev/null 2>&1 || log_error "Autentique: gh auth login"

echo ""
ghost_banner_release
echo ""

log_info "Passo 1: Gerando APK..."
bash "$SCRIPT_DIR/build-apk-on-vps.sh"

APK_FILE="/root/ghost-tunnel.apk"
[ -f "$APK_FILE" ] || log_error "APK não encontrado em $APK_FILE"

APK_SIZE=$(ls -lh "$APK_FILE" | awk '{print $5}')
APK_SHA=$(sha256sum "$APK_FILE" | awk '{print $1}')
log_success "APK gerado ($APK_SIZE)"

REPO_DIR="${GHOSTTUNNEL_REPO:-/opt/GhostTunnel}"
if [ ! -d "$REPO_DIR/.git" ]; then
  REPO_DIR="/tmp/GhostTunnel-release"
  git clone -q https://github.com/Samuel-Ziger/Proxy-vpn.git "$REPO_DIR"
fi

BUILD_HASH=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
APP_VERSION=$(node -p "require('$REPO_DIR/mobile/package.json').version" 2>/dev/null || echo "1.1.0")
VERSION="v${APP_VERSION}"
BUILD_DATE=$(date '+%d/%m/%Y %H:%M:%S')

RELEASE_NOTES="## GhostTunnel ${VERSION}

**Build**
- Data: ${BUILD_DATE}
- Commit: ${BUILD_HASH}
- Tamanho: ${APK_SIZE}
- SHA256: \`${APK_SHA}\`

**Instalação**
1. Baixe \`ghost-tunnel.apk\`
2. Instale no Android
3. Importe \`wg-client.conf\` no app
4. Toque em Conectar VPN

**Recursos**
- Cliente WireGuard nativo
- DNS AdGuard
- Storage criptografado de chaves
"

log_info "Passo 2: Publicando release $VERSION..."
if gh release view "$VERSION" --repo Samuel-Ziger/Proxy-vpn &>/dev/null; then
  log_warn "Release $VERSION existe — atualizando asset"
  gh release upload "$VERSION" "$APK_FILE#ghost-tunnel.apk" --repo Samuel-Ziger/Proxy-vpn --clobber
  gh release edit "$VERSION" --repo Samuel-Ziger/Proxy-vpn --notes "$RELEASE_NOTES"
else
  gh release create "$VERSION" \
    "$APK_FILE#ghost-tunnel.apk" \
    --repo Samuel-Ziger/Proxy-vpn \
    --title "GhostTunnel $VERSION" \
    --notes "$RELEASE_NOTES" \
    --latest
fi

DOWNLOAD_URL="https://github.com/Samuel-Ziger/Proxy-vpn/releases/download/${VERSION}/ghost-tunnel.apk"

echo ""
ghost_success_apk
echo ""
echo "Release: https://github.com/Samuel-Ziger/Proxy-vpn/releases/tag/${VERSION}"
echo "Download: $DOWNLOAD_URL"
echo "SHA256: $APK_SHA"
log_success "Release publicada (APK não commitado no Git)"
