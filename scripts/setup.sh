#!/bin/bash
# Portable VPN - ilk kurulum (macOS)
# Gerekli programi bin/ klasorune indirir; sisteme hicbir sey KURULMAZ.
# Ardindan ucretsiz Cloudflare WARP hesabi olusturup ayarlari hazirlar.
# macOS'un kendi bash 3.2'si ile uyumludur (10.13 High Sierra ve sonrasi).

set -e

SINGBOX_VERSION="1.14.2"
WGCF_VERSION="2.3.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/bin"
DATA="$ROOT/data"
TMP="$ROOT/tmp"
mkdir -p "$BIN" "$DATA" "$TMP"

say()  { printf '\033[36m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }

# --- Sistem bilgisi ---------------------------------------------------------
MACOS_VER="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VER%%.*}"
case "$(uname -m)" in
  arm64) ARCH="arm64" ;;
  *)     ARCH="amd64" ;;
esac
say "macOS $MACOS_VER ($ARCH)"

# --- sing-box (VPN motoru) --------------------------------------------------
SB="$BIN/sing-box"
if [ ! -x "$SB" ]; then
  NAME="sing-box-$SINGBOX_VERSION-darwin-$ARCH"
  # Yeni surumler macOS 12+ ister; daha eski Intel Mac'ler icin "legacy" surum var.
  if [ "$ARCH" = "amd64" ] && [ "$MACOS_MAJOR" -lt 12 ]; then
    NAME="$NAME-legacy-macos-10.13"
  fi
  say "sing-box indiriliyor ($NAME)..."
  curl -fL --progress-bar -o "$TMP/sb.tar.gz" \
    "https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/$NAME.tar.gz"
  tar -xzf "$TMP/sb.tar.gz" -C "$TMP"
  cp "$TMP/$NAME/sing-box" "$SB"
  chmod +x "$SB"
  xattr -d com.apple.quarantine "$SB" 2>/dev/null || true
  ok "sing-box hazir."
else
  ok "sing-box zaten var."
fi
"$SB" version | head -1

# --- Cloudflare WARP hesabi (ucretsiz) --------------------------------------
PROFILE="$DATA/wgcf-profile.conf"

register_with_wgcf() {
  WGCF="$BIN/wgcf"
  if [ ! -x "$WGCF" ]; then
    curl -fL --progress-bar -o "$WGCF" \
      "https://github.com/ViRb3/wgcf/releases/download/v$WGCF_VERSION/wgcf_${WGCF_VERSION}_darwin_$ARCH" || return 1
    chmod +x "$WGCF"
  fi
  ( cd "$DATA" && "$WGCF" register --accept-tos && "$WGCF" generate ) || return 1
  [ -f "$PROFILE" ]
}

# wgcf eski macOS'ta calismazsa: anahtari sing-box ile uret, kaydi curl ile yap.
register_with_curl() {
  KEYS="$("$SB" generate wg-keypair)" || return 1
  PRIV="$(printf '%s\n' "$KEYS" | sed -n 's/^PrivateKey: //p')"
  PUB="$(printf '%s\n' "$KEYS" | sed -n 's/^PublicKey: //p')"
  TOS="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  RESP="$(curl -fsS -X POST "https://api.cloudflareclient.com/v0a2158/reg" \
    -H 'User-Agent: okhttp/3.12.1' -H 'CF-Client-Version: a-6.10-2158' \
    -H 'Content-Type: application/json' \
    -d "{\"install_id\":\"\",\"fcm_token\":\"\",\"tos\":\"$TOS\",\"key\":\"$PUB\",\"type\":\"Android\",\"model\":\"PC\",\"locale\":\"en_US\"}")" || return 1
  # JSON'u macOS'un kendi JavaScript motoruyla oku (ek program gerekmez)
  PARSED="$(osascript -l JavaScript -e 'function run(a){var c=JSON.parse(a[0]).config;return [c.interface.addresses.v4,c.interface.addresses.v6,c.peers[0].public_key].join("\n")}' "$RESP")" || return 1
  V4="$(printf '%s\n' "$PARSED" | sed -n 1p)"
  V6="$(printf '%s\n' "$PARSED" | sed -n 2p)"
  PEER="$(printf '%s\n' "$PARSED" | sed -n 3p)"
  [ -n "$V4" ] && [ -n "$PEER" ] || return 1
  cat > "$PROFILE" <<CONF
[Interface]
PrivateKey = $PRIV
Address = $V4/32, $V6/128
MTU = 1280

[Peer]
PublicKey = $PEER
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = engage.cloudflareclient.com:2408
CONF
}

if [ ! -f "$PROFILE" ]; then
  say "Ucretsiz WARP hesabi olusturuluyor..."
  if register_with_wgcf 2>/dev/null; then
    ok "WARP hesabi hazir (wgcf)."
  else
    warn "wgcf bu macOS surumunde calismadi, alternatif yontem deneniyor..."
    if register_with_curl; then
      ok "WARP hesabi hazir."
    else
      warn "WARP hesabi olusturulamadi. DPI Bypass modu yine de calisir."
      warn "Baska bir cihazda 'wgcf register' ve 'wgcf generate' calistirip olusan"
      warn "wgcf-profile.conf dosyasini su klasore koyabilirsiniz: $DATA"
      rm -rf "$TMP"
      exit 1
    fi
  fi
else
  ok "WARP profili zaten var."
fi

"$ROOT/scripts/build-config.sh"
rm -rf "$TMP"
ok "Kurulum tamamlandi! Menuden bir mod secebilirsiniz."
