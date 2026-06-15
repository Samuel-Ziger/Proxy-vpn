# GhostTunnel

VPN pessoal com **WireGuard** na VPS e app Android nativo para conectar com **um toque**. Parte do ecossistema **Ghost** — privado, discreto e sob seu controle.

> Seu tráfego sai pela VPS. O cliente VPN roda dentro do próprio app — sem WireGuard externo.

---

## Visão geral

| Componente | Descrição |
|------------|-----------|
| **Servidor (VPS)** | WireGuard + UFW + Fail2Ban + hardening SSH |
| **App Android** | Cliente VPN nativo (`GoBackend` + `VpnService`) |
| **Scripts** | Instalação automatizada da VPS e build do APK |

```
Celular (GhostTunnel)
        │  UDP 51820
        ▼
   VPS Ubuntu/Debian
        │  NAT
        ▼
      Internet
```

---

## Funcionalidades

- Conexão VPN em **um toque** no Android
- Cliente WireGuard **embutido**
- Scripts de setup para VPS (Ubuntu/Debian)
- UFW + Fail2ban + hardening SSH
- `fix-vpn-nat.sh` para corrigir “sem internet”
- Chaves ficam **apenas no dispositivo**
- **DNS AdGuard** bloqueia ads, trackers, malware e phishing (quando conectado)

---

## Segurança em redes públicas

Com a VPN ativa:

- Tráfego **criptografado** até a VPS (Wi‑Fi público/corporativo)
- **DNS filtrado** — bloqueia domínios maliciosos, anúncios e rastreadores conhecidos
- **IP oculto** — sites veem o IP da sua VPS

Limitação: **cookies** não são bloqueados pela VPN (use navegador com proteção extra).

Detalhes: [docs/SECURITY.md](docs/SECURITY.md)

## Início rápido

### 1. VPS

```bash
git clone https://github.com/Samuel-Ziger/Proxy-vpn.git /opt/GhostTunnel
cd /opt/GhostTunnel/scripts
sudo bash install-vps-complete.sh
```

Chaves para o app:

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

Build na VPS:

```bash
sudo bash build-apk-on-vps.sh
scp usuario@IP_VPS:/root/ghost-tunnel.apk .
```

Build no PC: veja [mobile/README.md](mobile/README.md).

### 3. Conectar

1. Configuração da VPS → IP, porta `51820`, chaves
2. Salvar → **Conectar VPN**
3. Teste: https://ifconfig.me

---

## Estrutura

```
GhostTunnel/
├── mobile/          # App Android + plugin WireGuard nativo
├── scripts/         # Automação VPS e build APK
├── docs/            # Guia da VPS
└── releases/        # APKs (não versionados no Git)
```

Documentação:

- [Scripts](scripts/README.md)
- [App Android](mobile/README.md)
- [Setup da VPS](docs/VPS_SETUP.md)
- [Segurança e bloqueios](docs/SECURITY.md)

---

## Segurança

- SSH só com chave; root e senha desabilitados
- UFW deny incoming; só SSH + WireGuard
- Apague `/root/wg-client.conf` após configurar o celular
- Nunca commite chaves ou `.conf` com secrets
- Snapshot na DigitalOcean antes de mudanças

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| Sem internet | `sudo bash scripts/fix-vpn-nat.sh` |
| Sem handshake | Libere UDP 51820 na DigitalOcean |
| WireGuard parado | `sudo systemctl restart wg-quick@wg0` |
| Status | `sudo wg show` |

---

## Stack

WireGuard · Capacitor · `com.wireguard.android:tunnel` · UFW · Fail2ban

---

## Licença

MIT

**GhostTunnel** — túnel invisível, conexão sua.
