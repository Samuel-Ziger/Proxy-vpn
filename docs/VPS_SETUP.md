# GhostTunnel — Setup e segurança da VPS

Guia para preparar uma VPS (Debian/Ubuntu) como servidor WireGuard do **GhostTunnel**.

## Visão geral

- Objetivo: VPN pessoal para acessar a internet com segurança pelo celular (app GhostTunnel).
- Princípios: superfície mínima, SSH com chave, firewall restritivo, NAT correto, DNS local filtrado, PresharedKey, backups.

## Requisitos

- VPS Ubuntu ou Debian (recomendado **2 GB RAM**)
- Acesso SSH com sudo
- IP público
- Portas: **22/TCP** (SSH) e **51820/UDP** (WireGuard)

## Instalação automatizada (recomendado)

```bash
git clone https://github.com/Samuel-Ziger/Proxy-vpn.git /opt/GhostTunnel
cd /opt/GhostTunnel/scripts

sudo bash install-vps-complete.sh
# ou apenas WireGuard + UFW + NAT:
sudo bash install_wireguard.sh
```

Obter dados para o app:

```bash
curl -4 ifconfig.me
sudo cat /etc/wireguard/server_public.key
sudo cat /root/wg-client.conf
```

Apague o config da VPS após configurar o celular:

```bash
sudo rm -f /root/wg-client.conf /root/wg-client.png
```

## NAT / “sem internet” no celular

Se a VPN conecta mas o celular fica sem internet, o UFW está bloqueando o encaminhamento:

```bash
sudo bash /opt/GhostTunnel/scripts/fix-vpn-nat.sh
```

Desconecte e reconecte no app.

## Checklist de segurança

- SSH: `PermitRootLogin no`, `PasswordAuthentication no`, chave ed25519
- UFW: deny incoming; permitir só SSH e UDP 51820
- Fail2ban no SSH
- `unattended-upgrades` ativo
- Firewall da DigitalOcean alinhado com o UFW
- Snapshots antes de mudanças críticas
- Rotacionar chaves WireGuard se expostas

## Monitoramento

```bash
sudo wg show                    # handshake e tráfego
sudo systemctl status wg-quick@wg0
sudo ufw status verbose
sudo bash /opt/GhostTunnel/scripts/healthcheck-vps.sh
```

## Manutenção

- Rotacionar chaves: gere novo par, atualize `wg0.conf` e o app
- Revogar peer: remova a seção `[Peer]` e `sudo wg syncconf wg0`
- Resposta a incidente: snapshot, isolar VPS, recriar chaves, restaurar de backup limpo

## Referências

- [WireGuard](https://www.wireguard.com/)
- [Scripts do projeto](../scripts/README.md)
