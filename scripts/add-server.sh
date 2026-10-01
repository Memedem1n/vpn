#!/bin/bash
# "vless://..." baglantisindan kendi sunucunuz icin ayar dosyalarini uretir.
#   bash scripts/add-server.sh 'vless://...'
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$ROOT/data"
mkdir -p "$DATA"

LINK="$1"
if [ -z "$LINK" ]; then
  echo "Sunucu kurulumunun sonunda verilen vless:// baglantisini yapistirip Enter'a basin:"
  read -r LINK
fi
LINK="$(printf '%s' "$LINK" | tr -d ' \r\n')"
case "$LINK" in vless://*) ;; *) echo "[!] Baglanti vless:// ile baslamali."; exit 1 ;; esac

BODY="${LINK#vless://}"
BODY="${BODY%%#*}"
USERHOST="${BODY%%\?*}"
QUERY=""
case "$BODY" in *\?*) QUERY="${BODY#*\?}" ;; esac
UUID="${USERHOST%%@*}"
HOSTPORT="${USERHOST#*@}"
HOSTPORT="${HOSTPORT%/}"
PORT="${HOSTPORT##*:}"
HOST="${HOSTPORT%:*}"
HOST="${HOST#[}"; HOST="${HOST%]}"

param() { printf '%s\n' "$QUERY" | tr '&' '\n' | sed -n "s/^$1=//p" | head -1 | sed 's/%2F/\//g;s/%3D/=/g;s/%2B/+/g'; }
SECURITY="$(param security)"
SNI="$(param sni)"
PBK="$(param pbk)"
SID="$(param sid)"
FP="$(param fp)"; [ -z "$FP" ] && FP="chrome"
FLOW="$(param flow)"
TYPE="$(param type)"

if [ "$SECURITY" != "reality" ] || [ -z "$PBK" ] || [ -z "$UUID" ] || [ -z "$HOST" ]; then
  echo "[!] Bu baglanti desteklenmiyor. Sadece bu projenin server/install.sh ile kurulan"
  echo "    (VLESS + Reality) sunucularin baglantilari kabul edilir."
  exit 1
fi
if [ -n "$TYPE" ] && [ "$TYPE" != "tcp" ]; then echo "[!] Sadece type=tcp destekleniyor."; exit 1; fi

for MODE in tun proxy; do
  sed -e "s|__HOST__|$HOST|" -e "s|__PORT__|$PORT|" -e "s|__UUID__|$UUID|" \
      -e "s|__FLOW__|$FLOW|" -e "s|__SNI__|$SNI|" -e "s|__FP__|$FP|" \
      -e "s|__PBK__|$PBK|" -e "s|__SID__|$SID|" \
      "$ROOT/config/own-$MODE.template.json" > "$DATA/own-$MODE.json"
done
chmod 600 "$DATA"/own-*.json
echo "[+] Sunucu eklendi: $HOST:$PORT"

# Gecikme (ping) olcumu
if command -v nc >/dev/null 2>&1; then
  START=$(perl -MTime::HiRes=time -e 'printf "%d", time*1000' 2>/dev/null || echo 0)
  if nc -z -G 3 "$HOST" "$PORT" 2>/dev/null || nc -z -w 3 "$HOST" "$PORT" 2>/dev/null; then
    END=$(perl -MTime::HiRes=time -e 'printf "%d", time*1000' 2>/dev/null || echo 0)
    [ "$START" != 0 ] && echo "[+] Sunucuya erisiliyor, gecikme yaklasik $((END - START)) ms"
  else
    echo "[!] Sunucuya su an erisilemiyor (port $PORT). Sunucu acik mi?"
  fi
fi
