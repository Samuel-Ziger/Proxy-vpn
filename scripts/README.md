# 🚀 Scripts Automatizados - VPS + APK

Dois scripts all-in-one para deixar a VPS pronta e gerar o APK automaticamente.

## 📋 Resumo rápido

| Script | O que faz | Onde rodar |
|--------|-----------|-----------|
| `install-vps-complete.sh` | Instala WireGuard + configurações | **VPS** |
| `build-apk-on-vps.sh` | Gera APK Android | **VPS** |

---

## 🔧 Script 1: Setup Completo da VPS

**Arquivo:** `scripts/install-vps-complete.sh`

### O que é instalado:

✅ WireGuard (VPN)  
✅ UFW (Firewall)  
✅ Fail2Ban (Proteção contra brute-force)  
✅ SSH hardening (chaves, sem root, sem senha)  
✅ Unattended upgrades (atualizações automáticas)  
✅ Gera chaves e configuração do cliente  

### Como usar (uma linha):

```bash
# De uma máquina local:
ssh root@162.243.54.185 "bash <(curl -s https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/install-vps-complete.sh)"

# Ou, se já tiver acesso SSH:
ssh root@162.243.54.185
bash <(curl -s https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/install-vps-complete.sh)

# Ou manualmente:
wget -O /tmp/install-vps.sh https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/install-vps-complete.sh
sudo bash /tmp/install-vps.sh
```

### O que você recebe:

```
/root/wg-client.conf    <- Configuração do cliente (copie para seu celular)
/root/wg-client.png     <- QR code (escaneie com WireGuard app)
```

**Saída esperada:**
```
╔════════════════════════════════════════════════════════════╗
║              ✅ SETUP COMPLETO COM SUCESSO!               ║
╚════════════════════════════════════════════════════════════╝

IP Público:            162.243.54.185
Porta WireGuard:       51820
Chaves (salvas em /etc/wireguard/)
Servidor pública:      [suas chaves]
Cliente configurado:   /root/wg-client.conf

Próximos passos:
1. Baixe /root/wg-client.conf
2. Instale WireGuard no celular
3. Importe a config (QR ou arquivo)
4. Ative!
```

---

## 📱 Script 2: Build APK on VPS

**Arquivo:** `scripts/build-apk-on-vps.sh`

### O que é instalado:

✅ Node.js 18  
✅ Android SDK (completo)  
✅ Java JDK  
✅ Clona repositório  
✅ Compila o APK  
✅ Deixa pronto para download  

### Como usar (uma linha):

```bash
# De qualquer lugar (faz tudo automaticamente):
curl -O https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/build-apk-on-vps.sh
sudo bash build-apk-on-vps.sh

# Ou via SSH:
ssh root@162.243.54.185 "bash <(curl -s https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/build-apk-on-vps.sh)"
```

### Tempo estimado:
- ⏱️ Primeira vez: **~20-30 minutos** (instala Android SDK)
- ⏱️ Próximas vezes: **~5-10 minutos**

### O que você recebe:

```
/root/wireguard-vpn-manager.apk   <- APK pronto para instalar
```

**Saída esperada:**
```
╔════════════════════════════════════════════════════════════╗
║          ✅ APK GERADO COM SUCESSO!                       ║
╚════════════════════════════════════════════════════════════╝

📱 APK pronto:
Arquivo: /root/wireguard-vpn-manager.apk (75 MB)

📥 Formas de baixar:
1. Via SCP:
   scp root@162.243.54.185:/root/wireguard-vpn-manager.apk .

2. Via servidor HTTP:
   python3 /tmp/apk-server.py &
   http://162.243.54.185:8080/wireguard.apk

3. Via SSH + cat:
   ssh root@162.243.54.185 'cat /root/wireguard-vpn-manager.apk' > app.apk
```

---

## ⚡ Fluxo Completo (Rápido)

### 1️⃣ Setup VPS (primeira vez)
```bash
# Na VPS
curl -s https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/install-vps-complete.sh | sudo bash
```

### 2️⃣ Gerar APK (na VPS)
```bash
curl -s https://raw.githubusercontent.com/Samuel-Ziger/Proxy-vpn/main/scripts/build-apk-on-vps.sh | sudo bash
```

### 3️⃣ Baixar APK (do seu PC)
```bash
# Opção A: Via SCP
scp root@162.243.54.185:/root/wireguard-vpn-manager.apk .

# Opção B: Comando one-liner
ssh root@162.243.54.185 'cat /root/wireguard-vpn-manager.apk' > wireguard.apk
```

### 4️⃣ Instalar no Android
- Copie o APK para seu Android (USB, email, etc)
- Abra e instale
- Execute o app
- Preencha dados (IP, porta, chaves)
- Clique **Conectar** ✓

---

## 🔐 Segurança

### O que os scripts fazem:

✅ **SSH Hardening:**
- Desabilita root login
- Força autenticação por chave
- Sem senhas

✅ **Firewall:**
- Tudo bloqueado por padrão
- Apenas SSH + WireGuard liberados

✅ **Brute-force protection:**
- Fail2Ban ativado
- Max 5 tentativas antes de bloqueio

✅ **Atualizações automáticas:**
- Patches de segurança aplicados automaticamente

---

## 🐛 Troubleshooting

### "Permission denied"
```bash
# Adicione sudo
curl ... | sudo bash
```

### "Android SDK installation failed"
```bash
# Tente novamente (pode ser problema de download)
sudo bash build-apk-on-vps.sh
```

### "APK não instala no Android"
```bash
# Desinstale versão anterior e tente novamente
# Ou limpe cache: Settings > Apps > WireGuard VPN > Clear Cache
```

### "Não consigo conectar ao WireGuard"
```bash
# Verifique na VPS:
sudo wg show

# Veja os logs:
sudo tail -f /var/log/syslog
```

---

## 📊 Estrutura criada

Após rodar os scripts, sua VPS terá:

```
/etc/wireguard/
├── wg0.conf                 # Config do servidor
├── server_private.key
├── server_public.key
├── client_private.key
└── client_public.key

/root/
├── wg-client.conf           # Config do cliente
├── wg-client.png            # QR code
├── wireguard-vpn-manager.apk  # APK
└── build-apk-on-vps.sh      # Este script (para reusar)
```

---

## 🔄 Atualizar APP (depois)

Se fizer mudanças no app web, só rode novamente:

```bash
sudo bash /root/build-apk-on-vps.sh
# Novo APK será gerado em ~5 min
```

---

## ✅ Checklist de Setup

- [ ] Rodar `install-vps-complete.sh` na VPS
- [ ] Verificar `/root/wg-client.conf` foi gerado
- [ ] Baixar `/root/wg-client.conf` para seu PC
- [ ] Rodar `build-apk-on-vps.sh` na VPS
- [ ] Esperar ~20 min (primeira vez)
- [ ] Baixar `/root/wireguard-vpn-manager.apk`
- [ ] Instalar APK no Android
- [ ] Testar conexão VPN ✓

---

**Dúvidas?** Ver [docs/PROXY_VPN_SETUP.md](../docs/PROXY_VPN_SETUP.md) para detalhes técnicos.
