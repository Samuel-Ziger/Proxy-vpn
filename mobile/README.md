# GhostTunnel — App Android

Cliente VPN nativo para Android. Conecta à sua VPS com **um toque**, sem app WireGuard externo.

## Uso

1. Instale o APK (`releases/ghost-tunnel.apk`)
2. **Importe** o `wg-client.conf` da VPS (arquivo ou colar texto)
3. **Salvar** → **Conectar VPN**
4. Aceite a permissão VPN (primeira vez)
5. Ative **VPN sempre ativa** pelo botão nas configurações Android

Quando conectado: IP de saída real, servidor, tempo de sessão e DNS local filtrado.

## Build do APK

### Na VPS

```bash
cd /opt/GhostTunnel/scripts
sudo bash build-apk-on-vps.sh
```

### No PC

Requisitos: Node 22+, JDK 21+ (Android Studio Otter+), Android SDK 36, `ANDROID_HOME`

```bash
cd mobile
./build.sh
```

O script compila o plugin TypeScript, o frontend Vite e o APK debug.

**Windows (PowerShell):**

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
cd mobile
npm install
npm run build
npx cap sync android
cd android
.\gradlew.bat assembleDebug
Copy-Item app\build\outputs\apk\debug\app-debug.apk ..\..\releases\ghost-tunnel.apk
```

## Arquitetura

```
mobile/
├── plugins/capacitor-wireguard/   # Plugin nativo + storage criptografado
├── src/config.js                  # Validação e parse wg-client.conf
├── src/storage.js                 # EncryptedSharedPreferences via plugin
└── android/                       # Projeto Capacitor
```

## Segurança

- Chaves em **EncryptedSharedPreferences** (Android Keystore)
- `allowBackup="false"` no manifest
- `FLAG_SECURE` para bloquear screenshots/recents com chaves na tela
- Cleartext HTTP bloqueado por network security config
- PresharedKey WireGuard opcional importada do `wg-client.conf`
- DNS local filtrado (`10.0.0.1`) quando conectado
- Túnel IPv4 + IPv6 (`0.0.0.0/0, ::/0`)
- Cookies não são bloqueados — ver [docs/SECURITY.md](../docs/SECURITY.md)

## Release assinado

Defina:

```bash
export GHOSTTUNNEL_KEYSTORE_PATH=/caminho/ghosttunnel-release.jks
export GHOSTTUNNEL_KEYSTORE_PASSWORD=...
export GHOSTTUNNEL_KEY_ALIAS=ghosttunnel
export GHOSTTUNNEL_KEY_PASSWORD=...
```

Depois:

```bash
GRADLE_TASK=assembleRelease ./build.sh
```
