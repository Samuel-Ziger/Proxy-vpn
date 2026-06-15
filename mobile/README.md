# Proxy VPN — Cliente Android (WireGuard nativo)

App Android com **conexão VPN em um toque**. Não precisa do app WireGuard separado.

## Como funciona

1. Configure IP, porta e chaves da VPS (uma vez)
2. Toque em **Conectar VPN**
3. Na primeira vez, o Android pede permissão VPN — aceite
4. O túnel sobe direto pelo app

## Build do APK

### Na VPS Ubuntu (recomendado)

```bash
cd /opt/Proxy-vpn/scripts
sudo bash build-apk-on-vps.sh
```

APK gerado em `/root/proxy-vpn.apk`

### No PC (Android Studio + JDK 17)

```bash
cd mobile
npm install
npm run build
npx cap sync android
cd android
./gradlew assembleDebug   # Windows: gradlew.bat assembleDebug
```

APK em `mobile/android/app/build/outputs/apk/debug/app-debug.apk`

**Requisitos:** Node 18+, JDK 17, `ANDROID_HOME` configurado.

## Instalar no celular

```bash
scp ziger@IP_VPS:/root/proxy-vpn.apk .
```

Copie para o Android, instale e abra **Proxy VPN**.

## Dados da VPS

Na VPS:

```bash
curl -4 ifconfig.me
sudo cat /etc/wireguard/server_public.key
sudo cat /root/wg-client.conf   # se ainda existir
```

No app → **Configuração da VPS** → preencha e **Salvar**.

## Arquitetura

```
mobile/
├── plugins/capacitor-wireguard/   # Plugin nativo (GoBackend + VpnService)
├── android/                       # Projeto Capacitor Android
└── src/                           # UI (botão Conectar/Desconectar)
```

O plugin usa a biblioteca oficial `com.wireguard.android:tunnel`.

## Segurança

- Chaves ficam só no `localStorage` do dispositivo
- Nenhum dado é enviado para servidor externo
- Primeira conexão exige permissão VPN do Android (padrão do sistema)
