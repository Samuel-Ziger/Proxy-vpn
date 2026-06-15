#!/usr/bin/env bash
# Build Proxy VPN APK (cliente WireGuard nativo)

set -euo pipefail

echo "Proxy VPN - APK Builder"
echo "======================="

command -v node >/dev/null 2>&1 || { echo "Node.js não encontrado."; exit 1; }

echo "Node: $(node --version)"
echo "npm:  $(npm --version)"

npm install
npm run build
npx cap sync android

if [ -z "${ANDROID_HOME:-}" ]; then
  echo ""
  echo "ANDROID_HOME não configurado."
  echo "Instale Android Studio ou defina ANDROID_HOME."
  exit 1
fi

echo ""
echo "Compilando APK..."
cd android
chmod +x gradlew
./gradlew assembleDebug

APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
if [ -f "$APK_PATH" ]; then
  echo ""
  echo "APK gerado:"
  echo "  $(pwd)/$APK_PATH"
else
  echo "Falha: APK não encontrado."
  exit 1
fi
