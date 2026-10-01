#!/bin/bash
# Kendi VPN sunucunuzu kurar (VLESS + Reality, sing-box).
# Azerbaycan (veya baska bir ulke) konumlu, Ubuntu/Debian yuklu bir VPS'te
# root olarak calistirin:
#   curl -fL https://github.com/Memedem1n/vpn/raw/refs/heads/claude/determined-fermat-dsc8ie/server/install.sh | bash
# Sonunda verilen "vless://..." baglantisini Mac'teki menude 'Kendi sunucum' secenegine yapistirin.
set -e

SINGBOX_VERSION="1.14.2"
PORT="${PORT:-443}"
# Reality bu sitenin kimligine burunur; DPI trafigi bu siteye gidiyor sanir.
SNI="${SNI:-www.microsoft.com}"

[ "$(id -u)" = 0 ] || { echo "Lutfen root olarak calistirin (sudo -i)."; exit 1; }

case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Desteklenmeyen islemci: $(uname -m)"; exit 1 ;;
esac

NAME="sing-box-$SINGBOX_VERSION-linux-$ARCH"
cd /tmp
curl -fL -o sb.tar.gz "https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/$NAME.tar.gz"
tar -xzf sb.tar.gz
install -m 755 "$NAME/sing-box" /usr/local/bin/sing-box
rm -rf sb.tar.gz "$NAME"

mkdir -p /etc/sing-box
if [ -f /etc/sing-box/client.txt ]; then
  echo "Sunucu zaten kurulu, mevcut baglanti bilgisi korunuyor."
  UUID="$(sed -n 's/^UUID=//p' /etc/sing-box/client.txt)"
  PRIV="$(sed -n 's/^PRIV=//p' /etc/sing-box/client.txt)"
  PUB="$(sed -n 's/^PUB=//p' /etc/sing-box/client.txt)"
  SID="$(sed -n 's/^SID=//p' /etc/sing-box/client.txt)"
else
  UUID="$(sing-box generate uuid)"
  KEYS="$(sing-box generate reality-keypair)"
  PRIV="$(printf '%s\n' "$KEYS" | sed -n 's/^PrivateKey: //p')"
  PUB="$(printf '%s\n' "$KEYS" | sed -n 's/^PublicKey: //p')"
  SID="$(sing-box generate rand 8 --hex)"
  printf 'UUID=%s\nPRIV=%s\nPUB=%s\nSID=%s\n' "$UUID" "$PRIV" "$PUB" "$SID" > /etc/sing-box/client.txt
  chmod 600 /etc/sing-box/client.txt
fi

cat > /etc/sing-box/config.json <<CONF
{
  "log": { "level": "warn" },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $PORT,
      "users": [ { "uuid": "$UUID", "flow": "xtls-rprx-vision" } ],
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": { "server": "$SNI", "server_port": 443 },
          "private_key": "$PRIV",
          "short_id": [ "$SID" ]
        }
      }
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
CONF
sing-box check -c /etc/sing-box/config.json

cat > /etc/systemd/system/sing-box.service <<'UNIT'
[Unit]
Description=sing-box VPN server
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable sing-box >/dev/null 2>&1
systemctl restart sing-box

# Guvenlik duvari varsa portu ac
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q active; then ufw allow "$PORT"/tcp; fi

IP="$(curl -4 -fsS https://api.ipify.org || curl -4 -fsS https://ifconfig.me || hostname -I | awk '{print $1}')"
LINK="vless://$UUID@$IP:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUB&sid=$SID&type=tcp#PortableVPN"
echo "$LINK" > /etc/sing-box/link.txt

echo
echo "================ KURULUM TAMAM ================"
echo "Asagidaki baglantiyi kopyalayip Mac'teki menude"
echo "'Kendi sunucum' secenegine yapistirin:"
echo
echo "$LINK"
echo
echo "(Daha sonra tekrar gormek icin: cat /etc/sing-box/link.txt)"
