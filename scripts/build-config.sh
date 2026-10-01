#!/bin/bash
# data/wgcf-profile.conf dosyasindan WARP ayarlarini (data/warp-*.json) uretir.
#   --next : baglanti kurulamiyorsa bir sonraki WARP adresini/portunu dene
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$ROOT/data"
PROFILE="$DATA/wgcf-profile.conf"

if [ ! -f "$PROFILE" ]; then
  echo "[!] data/wgcf-profile.conf yok. Once kurulumu (secenek 1) calistirin."
  exit 1
fi

# Alan adi yerine IP kullaniyoruz: DNS engellense bile baglanabilsin.
# Bazi aglarda 2408 portu engelli olabiliyor, o yuzden alternatifler var.
ENDPOINTS="162.159.192.1:2408 162.159.192.1:500 162.159.192.1:1701 162.159.192.1:4500 162.159.195.1:2408 188.114.97.1:2408 188.114.98.1:500 162.159.192.1:878"
COUNT=$(echo $ENDPOINTS | wc -w | tr -d ' ')
IDX_FILE="$DATA/endpoint-index.txt"
IDX=0
[ -f "$IDX_FILE" ] && IDX="$(head -1 "$IDX_FILE" | tr -dc '0-9')"
[ -z "$IDX" ] && IDX=0
[ "$1" = "--next" ] && IDX=$(( (IDX + 1) % COUNT ))
[ "$IDX" -ge "$COUNT" ] && IDX=0
echo "$IDX" > "$IDX_FILE"
EP="$(echo $ENDPOINTS | cut -d' ' -f$((IDX + 1)))"
EP_HOST="${EP%:*}"
EP_PORT="${EP##*:}"

PRIV="$(sed -n 's/^[[:space:]]*PrivateKey[[:space:]]*=[[:space:]]*//p' "$PROFILE" | tr -d '[:space:]')"
PUB="$(sed -n 's/^[[:space:]]*PublicKey[[:space:]]*=[[:space:]]*//p' "$PROFILE" | tr -d '[:space:]')"
ADDRS="$(sed -n 's/^[[:space:]]*Address[[:space:]]*=[[:space:]]*//p' "$PROFILE" | tr ',' '\n' | tr -d ' \r')"
ADDR4="$(printf '%s\n' "$ADDRS" | grep -v ':' | grep . | head -1 || true)"
ADDR6="$(printf '%s\n' "$ADDRS" | grep ':' | head -1 || true)"

if [ -z "$PRIV" ] || [ -z "$PUB" ] || [ -z "$ADDR4" ]; then
  echo "[!] wgcf-profile.conf okunamadi veya eksik."
  exit 1
fi

for MODE in tun proxy; do
  # Base64 anahtarlarda "|" olmadigi icin sed ayraci olarak | kullaniliyor.
  if [ -n "$ADDR6" ]; then
    SED_V6="s|__ADDR6__|$ADDR6|"
  else
    SED_V6='/"__ADDR6__"/d;s|"__ADDR4__",|"__ADDR4__"|'
  fi
  sed -e "$SED_V6" -e "s|__ADDR4__|$ADDR4|" \
      -e "s|__PRIVATE_KEY__|$PRIV|" -e "s|__PEER_PUBLIC_KEY__|$PUB|" \
      -e "s|__ENDPOINT_HOST__|$EP_HOST|" -e "s|__ENDPOINT_PORT__|$EP_PORT|" \
      "$ROOT/config/warp-$MODE.template.json" > "$DATA/warp-$MODE.json"
done
chmod 600 "$DATA"/warp-*.json "$PROFILE"
echo "[+] WARP ayarlari hazir. Sunucu adresi: $EP"
