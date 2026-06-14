# WireGuard VPN Manager App

App web simples para gerenciar e conectar ao WireGuard VPN com um botão **Conectar**.

## Recursos

✅ Interface limpa e intuitiva  
✅ Gera e mostra QR code da configuração  
✅ Download direto da configuração (.conf)  
✅ Copiar para área de transferência  
✅ Validação de entrada (IP, porta, chaves)  
✅ Integração com app WireGuard (deep link)  
✅ Salva dados localmente (localStorage)  

## Como usar

### 1. Acesso direto (sem servidor)
Abra o arquivo `index.html` em seu navegador:
```bash
open app/index.html
# ou
firefox app/index.html
```

### 2. Com servidor Node.js (recomendado para mobile)
Instale as dependências:
```bash
npm install express cors
```

Rode o servidor:
```bash
node app/server.js
```

Acesse em: `http://localhost:3000`

### 3. Dados que você precisa

Para usar o app, você vai precisar:
- **IP da VPS**: ex. `162.243.54.185`
- **Porta WireGuard**: ex. `51820` (padrão)
- **Chave Privada do Cliente**: encontrada no `/root/wg-client.conf` ou gerada via `wg genkey`
- **Chave Pública do Servidor**: encontrada em `/etc/wireguard/server_public.key`

### 4. No seu smartphone

#### Android
1. Instale o app [WireGuard](https://play.google.com/store/apps/details?id=com.wireguard.android)
2. Abra este app web no navegador do celular
3. Preencha os dados da VPS
4. Clique em **Gerar Configuração**
5. Escaneie o QR code no WireGuard app OU clique em **Conectar**
6. Ative a conexão no WireGuard

#### iOS
1. Instale o app [WireGuard](https://apps.apple.com/app/wireguard/id1471933066)
2. Abra este app web no Safari
3. Preencha os dados e gere a configuração
4. Escaneie o QR code ou importe manualmente

## Fluxo de uso

```
1. Preencha os dados da VPS
   ↓
2. Clique "Gerar Configuração"
   ↓
3. Veja o QR code gerado
   ↓
4. Escolha uma opção:
   a) Escanear com WireGuard (recomendado)
   b) Copiar config e importar manualmente
   c) Baixar arquivo .conf
   ↓
5. Clique "Conectar" no WireGuard
```

## Segurança

⚠️ **Importante:**
- Este app funciona 100% no cliente (seu navegador). Nenhum dado é enviado para servidor.
- Suas chaves privadas **ficam apenas no seu dispositivo**.
- Use `localStorage` apenas se confia no dispositivo.
- **Nunca compartilhe suas chaves privadas**.

## Obter chaves da VPS

Se ainda não tem as chaves, execute na VPS:
```bash
# Obter chave pública do servidor
sudo cat /etc/wireguard/server_public.key

# Obter configuração do cliente (que contém a chave privada)
sudo cat /root/wg-client.conf
```

Copie os valores e cole no app.

## Troubleshooting

**Q: Deep link não funciona?**  
A: Deep links podem não funcionar em todos os navegadores. Copie e importe manualmente no WireGuard.

**Q: Código QR não aparece?**  
A: Verifique se todos os campos estão preenchidos corretamente. Atualize a página.

**Q: Dados desaparecem ao fechar o navegador?**  
A: Os dados são salvos em localStorage. Se foram apagados, refill o formulário.

## Arquitetura

```
app/
├── index.html      # Interface HTML
├── app.js          # Lógica JavaScript (gera QR, valida, etc)
├── style.css       # Estilos (gradient, responsivo)
├── server.js       # Servidor Node.js (opcional)
└── README.md       # Este arquivo
```

## Dependências

- **QRCode.js** (CDN): geração de QR code
- **Node.js** (opcional): para servir o app

## Próximas melhorias

- [ ] Status real da conexão (verificar via ping)
- [ ] Suporte para múltiplos profiles/VPS
- [ ] Sincronização com servidor
- [ ] App desktop (Electron)
- [ ] Temas dark/light
- [ ] Multi-idioma

---

**Criado com ❤️ para VPN segura e prática**
