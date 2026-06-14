# Configuração e segurança de VPS para Proxy / VPN (WireGuard)

Este documento descreve, em passos práticos, como preparar uma VPS (Debian/Ubuntu) para rodar um servidor VPN/Proxy usando WireGuard com foco em segurança operacional.

## Visão geral
- Objetivo: configurar WireGuard para acessar a Internet com mais segurança pelo celular ou outros dispositivos.
- Princípios: reduzir superfície de ataque, autenticação forte, firewall restritivo, atualização automática, monitoramento e backups.

## Requisitos mínimos
- VPS com Debian 13 ou Ubuntu (ex.: 1GB/2GB RAM).
- Acesso SSH como usuário com sudo.
- IP público da VPS.

## Recomendações rápidas
- Expor apenas SSH e a porta UDP do WireGuard.
- Usar SSH por chave (ed25519), `PermitRootLogin no`, `PasswordAuthentication no`.
- Firewall por padrão deny (UFW ou nftables). Permitir só portas necessárias.
- Instalar `fail2ban` e `unattended-upgrades`.
- Snapshots regulares e backups fora da VPS.

## Passos detalhados

1) Atualizar sistema e criar usuário sudo

```bash
sudo apt update && sudo apt upgrade -y
sudo adduser seuusuario
sudo usermod -aG sudo seuusuario
```

2) Configurar SSH (chaves, desabilitar root, mudar porta opcional)

No cliente:

```bash
ssh-keygen -t ed25519
ssh-copy-id -i ~/.ssh/id_ed25519.pub seuusuario@SUA_VPS_IP
```

Editar `/etc/ssh/sshd_config` e aplicar:

- `PermitRootLogin no`
- `PasswordAuthentication no`
- (opcional) `Port 2222`

Reiniciar SSH:

```bash
sudo systemctl restart sshd
```

3) Firewall básico com UFW

```bash
sudo apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
# permitir SSH (ajuste a porta se alterou)
sudo ufw allow 22/tcp
# permitir WireGuard
sudo ufw allow 51820/udp
sudo ufw enable
```

Se usar outra interface ou quiser NAT via UFW, ajuste `/etc/ufw/before.rules` (ver documentação UFW).

4) Proteção contra brute-force

```bash
sudo apt install fail2ban -y
# criar arquivo mínimo
sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null <<'EOF'
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOF
sudo systemctl restart fail2ban
```

5) Instalar WireGuard

```bash
sudo apt install wireguard qrencode -y
# gerar chaves no servidor
wg genkey | tee server_private.key | wg pubkey > server_public.key
# gerar chaves para o cliente (local ou no servidor)
wg genkey | tee client_private.key | wg pubkey > client_public.key
```

6) Exemplo de `/etc/wireguard/wg0.conf` (substitua chaves e `eth0`)

```
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
SaveConfig = true
```

Observações:
- Substitua `<SERVER_PRIVATE_KEY>` pelo conteúdo de `server_private.key`.
- Troque `eth0` pelo nome real da interface de saída (use `ip -o link show` para descobrir).

7) Habilitar forwarding permanente

```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

8) Exemplo de arquivo de cliente (`client.conf`)

```
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = SUA_VPS_IP:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

Gerar QR (no servidor) para importar no app WireGuard (Android/iOS):

```bash
qrencode -t ansiutf8 < client.conf
# ou gerar imagem
qrencode -o client.png < client.conf
```

9) Testar e habilitar

```bash
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
sudo wg show
```

10) Segurança adicional e manutenção
- Habilitar `unattended-upgrades` (`sudo apt install unattended-upgrades` e configurar `/etc/apt/apt.conf.d/50unattended-upgrades`).
- Instalar `rkhunter`, `aide` ou `tripwire` para integridade de sistema.
- Configurar logs/monitoramento (Logwatch, syslog remoto, ou um serviço de terceiros).
- Fazer snapshots automáticos do provedor antes de alterações.
- Rotacionar chaves WireGuard periodicamente; revogar peers removendo a entrada do peer e recarregando `wg`.

## Scripts e automação (opcional)
- É possível criar um script que automatize a instalação e gere as chaves/configs; tome cuidado com armazenamento seguro das chaves privadas.

## Playbook rápido de resposta
- Se detectar intrusão: isolar a VPS (dropar regras), tirar snapshot, coletar logs, recriar chaves, restaurar a partir de backup limpo.

## Referências
- WireGuard: https://www.wireguard.com/
- DigitalOcean Droplets (snapshots/backups)

---

Se quiser, posso também gerar um script de instalação automatizada (`install_wireguard.sh`) e o arquivo `client.conf` com chaves preenchidas — me informe qual VPS (Debian ou Ubuntu) e o IP público.
