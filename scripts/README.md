# GhostTunnel — Scripts

Automação para VPS e build do APK Android.

## Scripts

| Script | Função | Onde rodar |
|--------|--------|------------|
| `install-vps-complete.sh` | WireGuard + UFW + Fail2ban + SSH + NAT (canônico) | VPS |
| `install_wireguard.sh` | WireGuard mínimo (sem SSH hardening) | VPS |
| `fix-vpn-nat.sh` | Corrige “sem internet” (NAT/forward no UFW) | VPS |
| `enable-dns-filter.sh` | Atualiza DNS AdGuard no `wg-client.conf` | VPS |
| `add-peer.sh` | Adiciona segundo dispositivo | VPS |
| `rotate-keys.sh` | Rotaciona chaves do cliente principal | VPS |
| `build-apk-on-vps.sh` | Gera `ghost-tunnel.apk` | VPS |
| `build-and-push-apk.sh` | Build + GitHub Release (sem commit de APK) | VPS |

Arte ASCII: `ghost-art.sh`

## Setup da VPS (recomendado)

```bash
cd /opt/GhostTunnel/scripts
sudo bash install-vps-complete.sh
```

Reinstalar (regenera chaves — invalida clientes):

```bash
sudo bash install-vps-complete.sh --force
```

## Segundo dispositivo

```bash
sudo bash add-peer.sh tablet
# Config em /root/peers/wg-client-tablet.conf
```

## Rotacionar chaves

```bash
sudo bash rotate-keys.sh
```

## Corrigir sem internet

```bash
sudo bash fix-vpn-nat.sh
```

## Build do APK

**VPS:**

```bash
sudo bash build-apk-on-vps.sh
```

**PC:**

```bash
cd mobile && ./build.sh
```

**CI:** GitHub Actions em `.github/workflows/build-apk.yml`

## Release no GitHub

```bash
sudo bash build-and-push-apk.sh
```

Publica asset na Release — **não** commita APK no repositório.

## Portas

| Porta | Protocolo | Uso |
|-------|-----------|-----|
| 22 | TCP | SSH |
| 51820 | UDP | WireGuard |

Libere UDP 51820 também no firewall da cloud (DigitalOcean, etc.).
