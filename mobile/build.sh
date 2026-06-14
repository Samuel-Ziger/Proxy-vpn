#!/usr/bin/env bash
# Build WireGuard VPN Manager APK
# Requires: Node.js 18+, Java JDK, Android SDK

set -euo pipefail

echo "🔒 WireGuard VPN Manager - APK Builder"
echo "======================================"

# Check dependencies
echo "📋 Verificando dependências..."
command -v node >/dev/null 2>&1 || { echo "Node.js não encontrado. Instale em https://nodejs.org"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "npm não encontrado."; exit 1; }

echo "✓ Node.js: $(node --version)"
echo "✓ npm: $(npm --version)"

# Install dependencies
echo ""
echo "📦 Instalando dependências..."
npm install

# Build web app
echo ""
echo "🔨 Compilando app web..."
npm run build

# Check if Android SDK is available
if [ -z "${ANDROID_HOME:-}" ]; then
  echo ""
  echo "⚠️  ANDROID_HOME não configurado."
  echo "Configure: export ANDROID_HOME=/path/to/android-sdk"
  echo "Continuando com instalação Capacitor..."
else
  echo "✓ Android SDK: $ANDROID_HOME"
fi

# Add Android platform if not exists
echo ""
echo "📱 Adicionando plataforma Android..."
npx cap add android 2>/dev/null || true

# Sync files
echo ""
echo "🔄 Sincronizando arquivos para Android..."
npx cap sync android

# Build APK
echo ""
echo "🏗️  Compilando APK (debug)..."
npx cap build android

echo ""
echo "✅ Build concluído!"
echo ""
echo "📍 APK gerado em:"
echo "   android/app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "Próximos passos:"
echo "1. Copiar o APK para seu Android"
echo "2. Instalar no dispositivo"
echo "3. Abrir e preencher dados da VPS"
echo "4. Clicar 'Conectar' para usar com WireGuard"
echo ""
