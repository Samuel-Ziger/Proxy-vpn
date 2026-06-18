#!/usr/bin/env bash
# GhostTunnel - atualiza listas de bloqueio DNS locais para dnsmasq

set -euo pipefail

BLOCKLIST_CONF="/etc/dnsmasq.d/99-ghosttunnel-blocklist.conf"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "Execute como root: sudo bash update-dns-blocklist.sh" >&2
  exit 1
fi

command -v curl >/dev/null 2>&1 || {
  apt update
  apt install -y curl
}

URLS=(
  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  "https://urlhaus.abuse.ch/downloads/hostfile/"
)

RAW="$TMP_DIR/raw.txt"
DOMAINS="$TMP_DIR/domains.txt"
: > "$RAW"

for url in "${URLS[@]}"; do
  echo "Baixando lista: $url"
  curl -fsSL --retry 3 --max-time 45 "$url" >> "$RAW" || {
    echo "Aviso: falha ao baixar $url" >&2
  }
  printf '\n' >> "$RAW"
done

awk '
function valid_domain(domain) {
  return domain ~ /^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$/
}
{
  gsub(/\r/, "")
  line=$0
  sub(/[ \t]+#.*/, "", line)
  gsub(/^[ \t]+|[ \t]+$/, "", line)

  if (line == "" || line ~ /^#/ || line ~ /^!/ || line ~ /^@@/) next

  if (line ~ /^(0\.0\.0\.0|127\.0\.0\.1|::1)[ \t]+/) {
    split(line, parts, /[ \t]+/)
    for (i = 2; i <= length(parts); i++) {
      domain=tolower(parts[i])
      if (valid_domain(domain) && domain != "localhost") print domain
    }
    next
  }

  if (line ~ /^\|\|[A-Za-z0-9.-]+\^/) {
    domain=line
    sub(/^\|\|/, "", domain)
    sub(/\^.*/, "", domain)
    domain=tolower(domain)
    if (valid_domain(domain)) print domain
    next
  }

  if (line ~ /^[A-Za-z0-9.-]+$/) {
    domain=tolower(line)
    if (valid_domain(domain)) print domain
  }
}
' "$RAW" | sort -u > "$DOMAINS"

{
  echo "# GhostTunnel DNS blocklist"
  echo "# Gerado em: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  while IFS= read -r domain; do
    echo "address=/${domain}/0.0.0.0"
    echo "address=/${domain}/::"
  done < "$DOMAINS"
} > "$BLOCKLIST_CONF"

chmod 644 "$BLOCKLIST_CONF"
dnsmasq --test
systemctl restart dnsmasq

echo "Dominios bloqueados: $(wc -l < "$DOMAINS")"
echo "Arquivo: $BLOCKLIST_CONF"
