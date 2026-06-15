# GhostTunnel

VPN pessoal com **WireGuard** na VPS e app Android nativo para conectar com **um toque**. Parte do ecossistema **Ghost** — privado, discreto e sob seu controle.

> Seu tráfego sai pela VPS. O cliente VPN roda dentro do próprio app — sem WireGuard externo.

---

## Visão geral

| Componente | Descrição |
|------------|-----------|
| **Servidor (VPS)** | WireGuard + UFW + Fail2Ban + hardening SSH + NAT |
| **App Android** | Cliente VPN nativo (`GoBackend` + `VpnService`) |
| **Scripts** | Instalação da VPS, DNS filtrado e build do APK |

```
Celular (GhostTunnel)
        │  UDP 51820 (criptografado)
        ▼
   VPS Ubuntu/Debian
        │  NAT + DNS AdGuard
        ▼
      Internet
```

---

## Funcionalidades

### Servidor
- Setup automatizado (WireGuard, UFW, Fail2ban, SSH)
- `fix-vpn-nat.sh` corrige “sem internet” após conectar
- `enable-dns-filter.sh` ativa DNS AdGuard no cliente WireGuard

### App Android
- Conexão VPN em **um toque** (Conectar / Desconectar)
- Cliente WireGuard **embutido** — sem app externo
- **Importar `wg-client.conf`** (arquivo ou colar texto)
- Chaves em **EncryptedSharedPreferences** (Android Keystore)
- Tema dark Ghost, wizard de primeiro uso
- IP de **saída real** verificado após conectar
- IPv4 + IPv6 no túnel (`::/0`)
- Botão para abrir **VPN sempre ativa** nas configurações Android

### Proteção em rede
- Tráfego **criptografado** até a VPS (Wi‑Fi público/corporativo)
- **DNS AdGuard** — bloqueia ads, trackers, malware e phishing (domínios conhecidos)
- **IP de saída** = IP da sua VPS (`AllowedIPs = 0.0.0.0/0`)

Limitação: **cookies** não são bloqueados pela VPN — use navegador com proteção extra.

Detalhes: [docs/SECURITY.md](docs/SECURITY.md)

---

## Início rápido

### 1. VPS

```bash
git clone https://github.com/Samuel-Ziger/Proxy-vpn.git /opt/GhostTunnel
cd /opt/GhostTunnel/scripts
sudo bash install-vps-complete.sh
```

Ativar DNS filtrado no perfil do cliente:

```bash
sudo bash enable-dns-filter.sh
```

Dados para configurar o app:

```bash
curl -4 ifconfig.me
sudo cat /etc/wireguard/server_public.key
sudo cat /root/wg-client.conf
```

Sem internet após conectar:

```bash
sudo bash fix-vpn-nat.sh
```

### 2. APK no celular

APK gerado localmente: **`releases/ghost-tunnel.apk`** (não versionado no Git).

**Build na VPS:**

```bash
cd /opt/GhostTunnel/scripts
sudo bash build-apk-on-vps.sh
scp usuario@IP_VPS:/root/ghost-tunnel.apk .
```

**Build no Windows** (Node 18+, Android Studio / SDK):

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
cd mobile
npm install
npm run build
npx cap sync android
cd android
.\gradlew.bat assembleDebug
```

Copie o APK para `releases/`:

```powershell
Copy-Item mobile\android\app\build\outputs\apk\debug\app-debug.apk releases\ghost-tunnel.apk
```

**Linux/macOS:** `cd mobile && ./build.sh` — copia automaticamente para `releases/ghost-tunnel.apk`.

Mais detalhes: [mobile/README.md](mobile/README.md)

### 3. Conectar

1. Instale `ghost-tunnel.apk` no Android
2. **Importe** `/root/wg-client.conf` ou preencha IP/chaves manualmente
3. **Salvar** → **Conectar VPN** (aceite a permissão na primeira vez)
4. Confira o **IP de saída** no painel — deve ser o da VPS

### 4. Recomendado no Android

Em **Configurações → VPN → GhostTunnel**:

- **VPN sempre ativa**
- **Bloquear conexões sem VPN** (kill switch do sistema)

---

## Estrutura

```
GhostTunnel/
├── mobile/                    # App Capacitor + plugin WireGuard nativo
│   └── plugins/capacitor-wireguard/
├── scripts/                   # Automação VPS e build APK
├── docs/                      # Setup da VPS e modelo de segurança
└── releases/                  # ghost-tunnel.apk (local, ignorado no Git)
```

Documentação:

- [Scripts](scripts/README.md)
- [App Android](mobile/README.md)
- [Setup da VPS](docs/VPS_SETUP.md)
- [Segurança e bloqueios](docs/SECURITY.md)

---

## Segurança

- SSH só com chave; root e senha desabilitados
- UFW deny incoming; só SSH (22) + WireGuard (51820)
- Apague `/root/wg-client.conf` após configurar o celular
- Nunca commite chaves, `.conf` com secrets ou `*.apk`
- Rotacione chaves WireGuard se suspeitar de vazamento
- Snapshot na DigitalOcean antes de mudanças na VPS

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| Sem internet na VPN | `sudo bash scripts/fix-vpn-nat.sh` |
| DNS não filtra | `sudo bash scripts/enable-dns-filter.sh` e reconecte |
| Sem handshake | Libere UDP 51820 no UFW e no firewall da cloud |
| WireGuard parado | `sudo systemctl restart wg-quick@wg0` |
| Status do túnel | `sudo wg show` |
| Rede corporativa bloqueia VPN | UDP 51820 pode estar bloqueado — ver [SECURITY.md](docs/SECURITY.md) |

---

## Stack

WireGuard · Capacitor 6 · `com.wireguard.android:tunnel` · AdGuard DNS · UFW · Fail2ban

---

## Licença

MIT

**GhostTunnel** — túnel invisível, conexão sua.
