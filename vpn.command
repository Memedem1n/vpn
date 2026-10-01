#!/bin/bash
# Portable VPN menusu (macOS). Finder'da cift tiklayarak veya
# Terminal'de "bash vpn.command" yazarak calistirabilirsiniz.

cd "$(dirname "$0")" || exit 1
ROOT="$(pwd)"
SB="$ROOT/bin/sing-box"
DATA="$ROOT/data"
CONF="$ROOT/config"
PORT=2080
SB_PID=""

ok()   { printf '\033[32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }

pause() { echo; read -r -p "Menuye donmek icin Enter'a basin..." _; }

need_setup() {
  if [ ! -x "$SB" ]; then
    warn "Once kurulumu yapin (secenek 1)."
    return 0
  fi
  return 1
}

need_warp() {
  need_setup && return 0
  if [ ! -f "$DATA/warp-tun.json" ]; then
    warn "WARP ayarlari yok. Kurulumu (secenek 1) tekrar calistirin."
    return 0
  fi
  return 1
}

need_own() {
  need_setup && return 0
  if [ ! -f "$DATA/own-tun.json" ]; then
    warn "Henuz sunucu eklenmedi. Once secenek 8 ile sunucu baglantinizi ekleyin."
    return 0
  fi
  return 1
}

# --- Sistem proxy ayari (proxy modlari icin) ---------------------------------
services() { networksetup -listallnetworkservices 2>/dev/null | sed 1d | grep -v '^\*'; }

proxy_on() {
  local failed=0 s out
  while IFS= read -r s; do
    out="$(networksetup -setwebproxy "$s" 127.0.0.1 $PORT 2>&1;
           networksetup -setsecurewebproxy "$s" 127.0.0.1 $PORT 2>&1;
           networksetup -setsocksfirewallproxy "$s" 127.0.0.1 $PORT 2>&1)"
    case "$out" in *rror*|*privilege*) failed=1 ;; esac
  done <<LIST
$(services)
LIST
  if [ "$failed" = 1 ]; then
    warn "Sistem proxy ayari otomatik yapilamadi. Elle ayarlamak icin:"
    warn "  Sistem Tercihleri > Ag > Gelismis > Proxy'ler > SOCKS proxy: 127.0.0.1 port $PORT"
  else
    ok "Sistem proxy ayari acildi (127.0.0.1:$PORT)."
  fi
}

proxy_off() {
  local s
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    networksetup -setwebproxystate "$s" off >/dev/null 2>&1
    networksetup -setsecurewebproxystate "$s" off >/dev/null 2>&1
    networksetup -setsocksfirewallproxystate "$s" off >/dev/null 2>&1
  done <<LIST
$(services)
LIST
}

stop_proxy_mode() {
  [ -n "$SB_PID" ] && kill "$SB_PID" 2>/dev/null
  SB_PID=""
  proxy_off
  ok "Proxy kapatildi, sistem ayarlari eski haline getirildi."
}

open_discord_with_proxy() {
  if [ ! -d "/Applications/Discord.app" ] && [ ! -d "$HOME/Applications/Discord.app" ]; then
    warn "Discord uygulamasi bulunamadi. Tarayicida https://discord.com/app adresini kullanabilirsiniz."
    return
  fi
  pkill -x Discord 2>/dev/null && sleep 2
  open -a Discord --args --proxy-server="socks5://127.0.0.1:$PORT"
  ok "Discord proxy uzerinden acildi (sesli gorusme icin TAM mod daha saglikli)."
}

# --- Modlar -----------------------------------------------------------------
run_tun() {  # $1 = ayar dosyasi, $2 = aciklama
  echo
  ok "$2 baslatiliyor."
  echo "    Tum Mac trafigi (Discord sesli dahil) bu baglantidan gecer."
  echo "    Mac giris sifreniz istenecek (yazarken ekranda gorunmez)."
  echo "    KAPATMAK icin bu pencerede Ctrl+C'ye basin."
  echo
  trap ':' INT
  sudo "$SB" run -c "$1"
  trap - INT
  ok "Baglanti kapatildi."
  pause
}

run_proxy() {  # $1 = ayar dosyasi, $2 = aciklama
  echo
  ok "$2 baslatiliyor (sifre gerekmez)."
  echo "    Safari/Chrome gibi sistem proxy'sini kullanan uygulamalar bu baglantidan gecer."
  echo "    KAPATMAK icin bu pencerede Ctrl+C'ye basin. (Pencereyi direkt kapatirsaniz"
  echo "    menudeki 'Acil durum' (10) secenegiyle proxy ayarini sifirlayin.)"
  echo
  "$SB" run -c "$1" &
  SB_PID=$!
  sleep 2
  if ! kill -0 "$SB_PID" 2>/dev/null; then
    warn "Baslatilamadi. Ayni anda baska bir mod acik olabilir."
    SB_PID=""
    pause
    return
  fi
  trap 'stop_proxy_mode' INT TERM HUP
  proxy_on
  read -r -p "Discord uygulamasini da bu baglantiyla acayim mi? (e/h): " ans
  case "$ans" in e|E|evet|Evet) open_discord_with_proxy ;; esac
  echo
  echo "Baglanti acik. Kapatmak icin Ctrl+C..."
  wait "$SB_PID" 2>/dev/null
  trap - INT TERM HUP
  [ -n "$SB_PID" ] && stop_proxy_mode
  pause
}

emergency_reset() {
  proxy_off
  pkill -x sing-box 2>/dev/null
  if pgrep -x sing-box >/dev/null; then
    echo "Tam mod hala acik, kapatmak icin sifre istenecek:"
    sudo pkill -x sing-box
  fi
  ok "Tum baglantilar kapatildi ve proxy ayarlari sifirlandi."
  pause
}

# --- Menu -------------------------------------------------------------------
while true; do
  clear
  echo "=============================================================="
  echo "   PORTABLE VPN  -  kurulum gerektirmez, eski Mac'lerde calisir"
  echo "=============================================================="
  echo
  echo "  [1] Ilk kurulum / guncelleme (bir kere yapmaniz yeterli)"
  echo
  echo "  --- Discord ve engelli siteler (VPN degil, en hizli) ---"
  echo "  [2] DPI Bypass - TAM mod   (sifre ister, Discord sesli dahil)"
  echo "  [3] DPI Bypass - Proxy modu (sifre istemez, tarayici)"
  echo
  echo "  --- Gercek VPN (Cloudflare WARP, ucretsiz) ---"
  echo "  [4] WARP VPN - TAM mod     (sifre ister, her sey VPN'den gecer)"
  echo "  [5] WARP VPN - Proxy modu  (sifre istemez, tarayici)"
  echo
  echo "  --- Kendi sunucum (Azerbaycan vb., dusuk ping, TR disi IP) ---"
  echo "  [6] Kendi sunucum - TAM mod    (sifre ister, her sey)"
  echo "  [7] Kendi sunucum - Proxy modu (sifre istemez, tarayici)"
  echo "  [8] Kendi sunucumu ekle / degistir (vless:// baglantisi)"
  echo
  echo "  [9] WARP baglanmiyorsa: baska sunucu/port dene"
  echo "  [10] Acil durum: her seyi kapat, proxy ayarlarini sifirla"
  echo "  [0] Cikis"
  echo
  read -r -p "Seciminiz: " choice
  case "$choice" in
    1) bash "$ROOT/scripts/setup.sh"; pause ;;
    2) need_setup && { pause; continue; }; run_tun "$CONF/dpi-tun.json" "DPI Bypass (tam mod)" ;;
    3) need_setup && { pause; continue; }; run_proxy "$CONF/dpi-proxy.json" "DPI Bypass (proxy modu)" ;;
    4) need_warp && { pause; continue; }; run_tun "$DATA/warp-tun.json" "WARP VPN (tam mod)" ;;
    5) need_warp && { pause; continue; }; run_proxy "$DATA/warp-proxy.json" "WARP VPN (proxy modu)" ;;
    6) need_own && { pause; continue; }; run_tun "$DATA/own-tun.json" "Kendi sunucum (tam mod)" ;;
    7) need_own && { pause; continue; }; run_proxy "$DATA/own-proxy.json" "Kendi sunucum (proxy modu)" ;;
    8) bash "$ROOT/scripts/add-server.sh"; pause ;;
    9) bash "$ROOT/scripts/build-config.sh" --next; echo "Simdi 4 veya 5 ile tekrar deneyin."; pause ;;
    10) emergency_reset ;;
    0|q|Q) exit 0 ;;
  esac
done
