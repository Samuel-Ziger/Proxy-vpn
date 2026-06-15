# GhostTunnel — Scripts

Automação para VPS e build do APK Android.

## Scripts

| Script | Função | Onde rodar |
|--------|--------|------------|
| `install-vps-complete.sh` | WireGuard + UFW + Fail2ban + SSH hardening + NAT | VPS |
| `install_wireguard.sh` | WireGuard + UFW + NAT (setup mínimo) | VPS |
| `fix-vpn-nat.sh` | Corrige “sem internet” (NAT/forward no UFW) | VPS |
| `build-apk-on-vps.sh` | Gera `ghost-tunnel.apk` | VPS |
| `build-and-push-apk.sh` | Build + GitHub Release (requer `gh`) | VPS |
| `enable-dns-filter.sh` | Ativa DNS AdGuard no `wg-client.conf` | VPS |

Arte ASCII nos scripts: `ghost-art.sh` 👻

Documentação de segurança: [../docs/SECURITY.md](../docs/SECURITY.md)

## Setup da VPS

```bash
cd /opt/GhostTunnel/scripts
sudo bash install-vps-complete.sh
```

Arquivos gerados:

```
/etc/wireguard/wg0.conf
/root/wg-client.conf      # apague após configurar o app
/root/wg-client.png
```

## Corrigir sem internet

```bash
sudo bash fix-vpn-nat.sh
```

## Build do APK na VPS

```bash
sudo bash build-apk-on-vps.sh
```

Download:

```bash
scp usuario@IP_VPS:/root/ghost-tunnel.apk .
```

## Build no PC

```bash
cd mobile && ./build.sh
```

## Portas necessárias

| Porta | Protocolo | Uso |
|-------|-----------|-----|
| 22 | TCP | SSH |
| 51820 | UDP | WireGuard |

Libere também no firewall da DigitalOcean, se usar.
