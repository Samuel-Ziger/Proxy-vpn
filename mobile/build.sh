#!/usr/bin/env bash
# GhostTunnel — Build APK local

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/ghost-art.sh
source "$SCRIPT_DIR/../scripts/ghost-art.sh"

echo ""
ghost_banner_build_local
ghost_spinner_line "Invocando Gradle..."
echo ""

command -v node >/dev/null 2>&1 || { echo "Node.js nao encontrado."; exit 1; }
NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "Node.js 22+ e necessario para Capacitor 8. Atual: $(node --version)"
  exit 1
fi

cd "$SCRIPT_DIR"
npm install
npm run build
npx cap sync android

if [ -z "${ANDROID_HOME:-}" ]; then
  echo "ANDROID_HOME não configurado."
  exit 1
fi

cd android
chmod +x gradlew
GRADLE_TASK="${GRADLE_TASK:-assembleDebug}"
./gradlew "$GRADLE_TASK"

if [ "$GRADLE_TASK" = "assembleRelease" ]; then
  APK="app/build/outputs/apk/release/app-release.apk"
  if [ ! -f "$APK" ]; then
    APK="app/build/outputs/apk/release/app-release-unsigned.apk"
  fi
else
  APK="app/build/outputs/apk/debug/app-debug.apk"
fi
if [ -f "$APK" ]; then
  mkdir -p "$SCRIPT_DIR/../releases"
  cp "$APK" "$SCRIPT_DIR/../releases/ghost-tunnel.apk"
  echo ""
  ghost_success_apk
  echo ""
  echo "APK: $(pwd)/$APK"
  echo "Cópia: $SCRIPT_DIR/../releases/ghost-tunnel.apk"
else
  echo "Falha: APK não encontrado."
  exit 1
fi
