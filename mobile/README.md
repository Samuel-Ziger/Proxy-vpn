# GhostTunnel — App Android

Cliente VPN nativo para Android. Conecta à sua VPS com **um toque**, sem app WireGuard externo.

## Uso

1. Instale o APK (`ghost-tunnel.apk`)
2. **Configuração da VPS** → IP, porta `51820`, chaves
3. **Salvar** → **Conectar VPN**
4. Aceite a permissão VPN (primeira vez)

Teste: https://ifconfig.me deve mostrar o IP da VPS.

## Build do APK

### Na VPS

```bash
cd /opt/GhostTunnel/scripts
sudo bash build-apk-on-vps.sh
```

Saída: `/root/ghost-tunnel.apk`

### No PC

Requisitos: Node 18+, JDK 17+, `ANDROID_HOME`

```bash
cd mobile
npm install
npm run build
npx cap sync android
cd android
./gradlew assembleDebug    # Windows: gradlew.bat assembleDebug
```

APK: `android/app/build/outputs/apk/debug/app-debug.apk`

Ou use `./build.sh`.

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
