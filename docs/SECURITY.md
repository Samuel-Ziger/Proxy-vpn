# GhostTunnel — Modelo de segurança

## Objetivo

Proteger você em **redes públicas** (café, aeroporto) e **corporativas** (Wi‑Fi da empresa) com:

1. **Túnel criptografado** até sua VPS (ninguém na rede local lê o tráfego)
2. **IP de saída** da sua VPS (sites não veem o IP da operadora/local)
3. **DNS filtrado** — bloqueia domínios de malware, phishing, anúncios e rastreadores conhecidos

---

## O que está protegido

| Ameaça | Como o GhostTunnel ajuda |
|--------|--------------------------|
| Sniffing em Wi‑Fi público | Tráfego criptografado (WireGuard) até a VPS |
| ISP/rede local vendo sites visitados | Destinos ficam dentro do túnel; saída pelo IP da VPS |
| Malware / phishing (domínios conhecidos) | DNS local filtrado bloqueia listas atualizadas |
| Anúncios (domínios de ad-server) | DNS local filtrado bloqueia redes de ads |
| Rastreadores (domínios) | DNS bloqueia `google-analytics`, pixels, etc. |
| DNS manipulado pela rede | Consultas DNS passam pelo túnel (config do app) |

---

## O que NÃO bloqueia (limites honestos)

| Item | Por quê |
|------|---------|
| **Cookies** | São gravados pelo navegador/app no celular. VPN não vê conteúdo HTTPS nem cookies. Use modo privado ou bloqueador no browser. |
| **Fingerprinting** | Canvas, fontes, etc. — precisa de configuração do navegador (Firefox strict, Brave, etc.) |
| **Sites em IP direto** | DNS filter não ajuda se alguém acessa por IP numérico |
| **Apps que ignoram VPN** | Raro no Android com túnel completo (`0.0.0.0/0`) |
| **Conteúdo dentro de HTTPS** | A VPS roteia pacotes; não descriptografa sites |
| **IPv6 sem rota pública na VPS** | O túnel usa IPv6 ULA, mas egress IPv6 externo só funciona se a VPS tiver IPv6 público e NAT/forward aplicado. Teste leak após conectar. |

---

## DNS usado (padrão forte)

**DNS local na VPS:**

```ini
DNS = 10.0.0.1
```

O script `enable-dns-filter.sh` instala `dnsmasq` escutando na interface `wg0`, usa upstream filtrado e aplica listas locais geradas por `update-dns-blocklist.sh`.

Vantagem: o celular consulta DNS dentro do túnel, a rede local não vê consultas DNS e você controla listas/allowlist/blocklist na própria VPS.

**Fallback público opcional:**

```bash
sudo bash /opt/GhostTunnel/scripts/enable-dns-filter.sh --public
```

Isso usa AdGuard DNS (`94.140.14.14`, `94.140.15.15`) diretamente no perfil do cliente.

---

## Redes públicas e corporativas

### Wi‑Fi público
- Sem VPN: qualquer um na mesma rede pode tentar interceptar tráfego não criptografado.
- Com GhostTunnel: dados entre celular e VPS são criptografados; a rede local só vê UDP para sua VPS.

### Rede corporativa
- A empresa pode bloquear UDP 51820 (WireGuard) — nesse caso o túnel não conecta.
- Se conectar: seu tráfego de navegação sai pelo IP da VPS, não pelo firewall corporativo (política da empresa pode proibir VPN — verifique regras internas).

---

## Recomendações extras

1. **Always-on VPN** (Android): Configurações → VPN → GhostTunnel → sempre ativo
2. **Bloquear sem VPN**: mesma tela → “Bloquear conexões sem VPN” (kill switch do sistema)
3. **Navegador**: Firefox + uBlock Origin ou Brave para camada extra anti-tracker/cookie
4. **HTTPS**: nunca ignore avisos de certificado
5. **Rotacione chaves** se suspeitar de vazamento

---

## Atualizar DNS na VPS já em uso

Edite o app (reconecte) ou `/root/wg-client.conf`:

```ini
DNS = 10.0.0.1
```

Ou rode na VPS:

```bash
sudo bash /opt/GhostTunnel/scripts/enable-dns-filter.sh
sudo bash /opt/GhostTunnel/scripts/update-dns-blocklist.sh
```
