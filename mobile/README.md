# GhostTunnel — App Android

Cliente VPN nativo para Android. Conecta à sua VPS com **um toque**, sem app WireGuard externo.

## Uso

1. Instale o APK (`releases/ghost-tunnel.apk`)
2. **Configuração da VPS** → IP, porta `51820`, chaves do `wg-client.conf`
3. **Salvar** → **Conectar VPN**
4. Aceite a permissão VPN (primeira vez)

Quando conectado, o app mostra IP público, servidor, tempo de sessão e DNS AdGuard ativo.

Teste: https://ifconfig.me deve mostrar o IP da VPS.

**Recomendado:** Configurações → VPN → GhostTunnel → VPN sempre ativa + bloquear sem VPN.

## Build do APK

### Na VPS

```bash
cd /opt/GhostTunnel/scripts
sudo bash build-apk-on-vps.sh
```

Saída: `/root/ghost-tunnel.apk`

### No PC

Requisitos: Node 18+, JDK 17+ (Android Studio), `ANDROID_HOME`

**Linux/macOS:**

```bash
cd mobile
./build.sh
```

Copia o APK para `../releases/ghost-tunnel.apk`.

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

APK de build: `android/app/build/outputs/apk/debug/app-debug.apk`

## Arquitetura

```
mobile/
├── plugins/capacitor-wireguard/   # Plugin nativo (GoBackend + VpnService)
├── android/                       # Projeto Capacitor
└── src/                           # UI (Conectar / Desconectar)
```

Biblioteca: `com.wireguard.android:tunnel`

## Segurança

- Chaves salvas apenas no `localStorage` do dispositivo
- Nenhum dado enviado a servidores externos
- Permissão VPN exigida pelo Android na primeira conexão
- DNS AdGuard (`94.140.14.14`, `94.140.15.15`) quando conectado — filtra malware, ads e trackers
- Cookies não são bloqueados pela VPN — ver [docs/SECURITY.md](../docs/SECURITY.md)
