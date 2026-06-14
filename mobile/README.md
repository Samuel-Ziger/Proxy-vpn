# WireGuard VPN Manager - APK (Android)

App nativo Android para gerenciar e conectar ao WireGuard VPN.

## 📱 Características

- ✅ Interface touch-friendly para mobile
- ✅ Geração de QR code para WireGuard
- ✅ Deep linking para abrir WireGuard app
- ✅ Armazenamento local de configuração
- ✅ Suporte para notch/safe areas
- ✅ Otimizado para baixo consumo de bateria

## 🚀 Pré-requisitos

Para compilar o APK, você precisa:

1. **Node.js 18+** — [Download](https://nodejs.org/)
2. **Android Studio** — [Download](https://developer.android.com/studio)
3. **Android SDK** — instalado via Android Studio
4. **Java JDK** — incluído com Android Studio

### Setup no macOS/Linux

```bash
# Instalar Node.js
brew install node

# Instalar Android Studio
brew install --cask android-studio

# Configure ANDROID_HOME
export ANDROID_HOME=$HOME/Library/Android/sdk  # macOS
# ou
export ANDROID_HOME=$HOME/Android/Sdk  # Linux
```

### Setup no Windows

1. Instale [Node.js](https://nodejs.org/)
2. Instale [Android Studio](https://developer.android.com/studio)
3. Configure `ANDROID_HOME`:
   - Windows: `setx ANDROID_HOME "%USERPROFILE%\AppData\Local\Android\Sdk"`

## 📦 Build do APK

### Opção 1: Build Automático (Recomendado)

```bash
cd mobile
chmod +x build.sh
./build.sh
```

### Opção 2: Build Manual

```bash
cd mobile

# 1. Instalar dependências
npm install

# 2. Build web app
npm run build

# 3. Adicionar plataforma Android (primeira vez)
npm run cap:add:android

# 4. Sincronizar arquivos
npm run cap:sync

# 5. Compilar APK
npm run cap:build

# (Opcional) Abrir Android Studio
npm run cap:open
```

## 📁 Saída do Build

Após a compilação, o APK estará em:

```
mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

## 📲 Instalar no Android

### Via USB

```bash
# Conecte o dispositivo Android via USB
# Ative "Depuração de USB" nas configurações do dispositivo

# Instale o APK
adb install mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

### Via Arquivo

1. Copie `app-debug.apk` para seu Android (ex: via email, WhatsApp, etc.)
2. Abra o arquivo no gestor de arquivos do Android
3. Toque em **Instalar**
4. Permita a instalação de fontes desconhecidas se pedido

## 🔐 Assinatura de Release (APK Release)

Para distribuir via Google Play Store:

```bash
# 1. Criar keystore (uma vez)
keytool -genkey -v -keystore wireguard.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias wireguard

# 2. Build de release
cd mobile/android
./gradlew bundleRelease \
  -Pandroid.injected.signing.store.file=../../wireguard.keystore \
  -Pandroid.injected.signing.store.password=SENHA \
  -Pandroid.injected.signing.key.alias=wireguard \
  -Pandroid.injected.signing.key.password=SENHA
```

## 💾 Dados Salvos

O app salva automaticamente em `localStorage`:
- IP da VPS
- Porta
- Chaves (localmente, **nunca** enviadas para servidor)

## 🐛 Troubleshooting

### "ANDROID_HOME not found"
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk  # macOS
export ANDROID_HOME=$HOME/Android/Sdk          # Linux
export ANDROID_HOME=%USERPROFILE%\AppData\Local\Android\Sdk  # Windows
```

### "Gradle build failed"
```bash
cd mobile/android
./gradlew clean
cd ..
npm run cap:build
```

### "APK não instala"
- Desinstale a versão anterior: `adb uninstall com.wireguard.vpnmanager`
- Tente novamente

### "WireGuard não abre"
- Verifique se o app WireGuard está instalado
- Configure manualmente: copie a config e importe no WireGuard app

## 📦 Estrutura

```
mobile/
├── src/                    # Código fonte web
│   ├── index.html
│   ├── app.js
│   └── style.css
├── dist/                   # Build web (gerado)
├── android/                # Projeto Android (gerado por Capacitor)
├── package.json
├── vite.config.js
├── capacitor.config.json
├── build.sh
└── README.md
```

## 🔄 Desenvolvimento

### Dev mode (web)
```bash
cd mobile
npm run dev
# Acessa http://localhost:3000
```

### Debug no Android
```bash
npm run cap:run
# Abre app em tempo real com log
```

## 📄 Licença

MIT — Use livremente para fins pessoais e comerciais.

---

**Pronto?** Comece com `./build.sh` e você terá o APK em minutos! 🚀
