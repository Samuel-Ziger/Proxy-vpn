#!/usr/bin/env bash
# GhostTunnel — ASCII art compartilhado
# Uso: source "$(dirname "$0")/ghost-art.sh"

GHOST_CYAN='\033[0;36m'
GHOST_PURPLE='\033[0;35m'
GHOST_DIM='\033[0;90m'
GHOST_NC='\033[0m'

ghost_logo_small() {
  echo -e "${GHOST_CYAN}"
  cat <<'EOF'
       .---.
      /     \      👻
     | o   o |
      \  ~  /     GhostTunnel
       '---'
EOF
  echo -e "${GHOST_NC}"
}

ghost_banner_vps() {
  echo -e "${GHOST_PURPLE}"
  cat <<'EOF'
   ╔═══════════════════════════════════════════════════════╗
   ║                                                       ║
   ║     .---.         G H O S T T U N N E L              ║
   ║    /     \        ─────────────────────              ║
   ║   | o   o |       VPS Setup • WireGuard              ║
   ║    \  ~  /        Instalação automática              ║
   ║     '---'                                            ║
   ║                                                       ║
   ╚═══════════════════════════════════════════════════════╝
EOF
  echo -e "${GHOST_NC}"
}

ghost_banner_apk() {
  echo -e "${GHOST_PURPLE}"
  cat <<'EOF'
   ╔═══════════════════════════════════════════════════════╗
   ║                                                       ║
   ║    📱  .---.      G H O S T T U N N E L              ║
   ║       /     \     APK Builder                        ║
   ║      | o   o |    ~15-20 min ☕                       ║
   ║       \  ~  /                                        ║
   ║        '---'                                          ║
   ║                                                       ║
   ╚═══════════════════════════════════════════════════════╝
EOF
  echo -e "${GHOST_NC}"
}

ghost_banner_nat() {
  echo -e "${GHOST_YELLOW:-\033[0;33m}"
  cat <<'EOF'
        .---.
       /  !  \     🔧 Fix NAT
      | o   o |    "sem internet" → resolvido
       \  ~  /
        '---'
   Celular ══► VPS ══► Internet
EOF
  echo -e "${GHOST_NC}"
}

ghost_banner_wireguard() {
  echo -e "${GHOST_CYAN}"
  cat <<'EOF'
   ╔════════════════════════════════════════╗
   ║  👻 GhostTunnel — WireGuard Quick      ║
   ║     Setup mínimo + UFW + NAT           ║
   ╚════════════════════════════════════════╝
EOF
  echo -e "${GHOST_NC}"
}

ghost_banner_release() {
  echo -e "${GHOST_PURPLE}"
  cat <<'EOF'
   ╔═══════════════════════════════════════════════════════╗
   ║   🚀  .---.     GhostTunnel → GitHub Release         ║
   ║      /     \                                         ║
   ║     | o   o |    build → push → download             ║
   ║      \  ~  /                                         ║
   ║       '---'                                          ║
   ╚═══════════════════════════════════════════════════════╝
EOF
  echo -e "${GHOST_NC}"
}

ghost_tunnel_flow() {
  echo -e "${GHOST_DIM}"
  cat <<'EOF'
        ┌──────────┐    UDP 51820    ┌──────────┐
        │ 📱 Você  │ ═══════════════►│ 🖥️  VPS  │
        └──────────┘                 └────┬─────┘
                                          │ NAT
                                          ▼
                                    🌐 Internet
EOF
  echo -e "${GHOST_NC}"
}

ghost_success_vps() {
  echo -e "${GHOST_GREEN:-\033[0;32m}"
  cat <<'EOF'
   ╔═══════════════════════════════════════════════════════╗
   ║                                                       ║
   ║      ✅  .---.                                        ║
   ║         /  ✓  \     VPS PRONTA!                      ║
   ║        | o   o |                                      ║
   ║         \  ~  /     GhostTunnel online               ║
   ║          '---'                                        ║
   ║                                                       ║
   ╚═══════════════════════════════════════════════════════╝
EOF
  echo -e "${GHOST_NC}"
  ghost_tunnel_flow
}

ghost_success_apk() {
  echo -e "${GHOST_GREEN:-\033[0;32m}"
  cat <<'EOF'
   ╔═══════════════════════════════════════════════════════╗
   ║                                                       ║
   ║     📦  .---.     APK GERADO!                         ║
   ║        /     \                                        ║
   ║       | o   o |    Instale no Android                ║
   ║        \  ~  /     → Conectar VPN                    ║
   ║         '---'                                         ║
   ║                                                       ║
   ╚═══════════════════════════════════════════════════════╝
EOF
  echo -e "${GHOST_NC}"
}

ghost_success_nat() {
  echo -e "${GHOST_GREEN:-\033[0;32m}"
  cat <<'EOF'
      .---.
     /  ✓  \    NAT corrigido!
    | o   o |   Reconecte no celular 👻
     \  ~  /
      '---'
EOF
  echo -e "${GHOST_NC}"
}

ghost_spinner_line() {
  local msg="${1:-Trabalhando...}"
  echo -e "${GHOST_DIM}   👻 ${msg}${GHOST_NC}"
}

ghost_banner_build_local() {
  echo -e "${GHOST_CYAN}"
  cat <<'EOF'
   .---.   GhostTunnel — Build Local
  /     \  ────────────────────────
 | o   o | npm → vite → gradle → apk
  \  ~  /
   '---'
EOF
  echo -e "${GHOST_NC}"
}
