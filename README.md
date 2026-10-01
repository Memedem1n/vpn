# Portable VPN (macOS)

Eski Mac'lerde VPN uygulaması kurulamadığında kullanmak için hazırlandı. **Hiçbir şey kurulmaz**:
tek bir program (açık kaynak [sing-box](https://github.com/SagerNet/sing-box)) bu klasörün içine indirilir
ve oradan çalışır. Klasörü silerseniz her şey gider.

- macOS **10.13 High Sierra ve sonrası** (Intel ve Apple Silicon)
- Ücretsiz, hesap/üyelik gerekmez
- Arka planda servis çalışmaz; ihtiyaç olduğunda açıp, işiniz bitince kapatırsınız
- Eski bilgisayarı yormaz (sing-box ~20–40 MB RAM kullanır)

## İki çözüm var

| Mod | Ne işe yarar | Hız |
|---|---|---|
| **DPI Bypass** | Discord ve DNS/SNI ile engellenen siteler. VPN değildir; trafiğiniz yine kendi internetinizden çıkar, sadece engel aşılır. | En hızlı |
| **WARP VPN** | Gerçek VPN (Cloudflare WARP, ücretsiz). IP adresiniz değişir, tüm trafik şifreli tünelden geçer. İş için VPN gerektiğinde bunu kullanın. | Biraz daha yavaş |

Her birinin iki çalışma şekli var:

- **TAM mod** — Mac'in tüm trafiği (Discord uygulaması ve **sesli görüşme dahil**) geçer. Mac giriş şifrenizi ister (`sudo`).
- **Proxy modu** — Şifre istemez. Safari/Chrome gibi sistem proxy'sini kullanan uygulamalar geçer.
  Discord'u da bu modda proxy ile açmayı teklif eder, ama sesli görüşme için TAM mod daha sağlıklıdır.

> **Discord + iş aynı anda:** Discord'u açık tutmak için **DPI Bypass – TAM mod** yeterli ve en hafifidir.
> İş için VPN gerekirse onu kapatıp **WARP VPN – TAM mod**'u açın; WARP açıkken Discord da onun üzerinden çalışmaya devam eder.
> Aynı anda sadece bir mod açık olabilir.

## Kurulum (bir kere)

Terminal'i açın (Spotlight → "Terminal") ve şunu yapıştırın:

```bash
mkdir -p ~/PortableVPN && cd ~/PortableVPN && \
curl -L https://github.com/memedem1n/vpn/archive/HEAD.tar.gz | tar xz --strip-components=1 && \
bash vpn.command
```

Açılan menüde önce **1**'e basın. Gerekli dosyalar indirilir ve ücretsiz WARP hesabı otomatik oluşturulur.

> Depo gizliyse yukarıdaki komut çalışmaz: GitHub'da **Code → Download ZIP** ile indirip açın,
> sonra Terminal'de `cd` ile klasöre girip `bash vpn.command` yazın.

## Kullanım

Sonraki seferlerde Terminal'de:

```bash
bash ~/PortableVPN/vpn.command
```

(veya Finder'da `vpn.command` dosyasına çift tıklayın — ilk seferde macOS uyarı verirse sağ tık → **Aç**.)

```
  [1] Ilk kurulum / guncelleme
  [2] DPI Bypass - TAM mod     (sifre ister, Discord sesli dahil)
  [3] DPI Bypass - Proxy modu  (sifre istemez, tarayici)
  [4] WARP VPN - TAM mod       (sifre ister, her sey VPN'den gecer)
  [5] WARP VPN - Proxy modu    (sifre istemez, tarayici)
  [6] WARP baglanmiyorsa: baska sunucu/port dene
  [7] Acil durum: her seyi kapat, proxy ayarlarini sifirla
```

**Kapatmak için** bağlantının açık olduğu Terminal penceresinde **Ctrl+C**'ye basın.

## Sorun giderme

- **WARP bağlanmıyor / sayfalar açılmıyor:** Menüden **6**'yı seçip tekrar deneyin. Farklı Cloudflare adresleri ve portları sırayla denenir.
- **İnternet tamamen gitti:** Menüden **7** (Acil durum). Proxy ayarlarını sıfırlar ve açık kalan bağlantıyı kapatır.
- **Discord uygulaması bu macOS sürümünde açılmıyor:** Discord yeni sürümleri eski macOS'u desteklemeyebilir.
  DPI Bypass – TAM mod açıkken tarayıcıda <https://discord.com/app> kullanın; sesli görüşme de çalışır.
- **"WARP hesabı oluşturulamadı":** Başka bir cihazda [wgcf](https://github.com/ViRb3/wgcf) ile
  `wgcf register` ve `wgcf generate` çalıştırıp oluşan `wgcf-profile.conf` dosyasını `~/PortableVPN/data/` içine koyun,
  sonra kurulumu (1) tekrar çalıştırın. DPI Bypass modu WARP olmadan da çalışır.
- **Şirket VPN'i gerekiyorsa** (şirket ağına erişim): WARP sadece genel amaçlı VPN'dir, şirketin iç ağına bağlamaz.

## Nasıl çalışıyor?

- `config/dpi-*.json` — Doğrudan bağlantı + şifreli DNS (DoH, 1.1.1.1) + TLS el sıkışmasını parçalama.
  Engel DNS'te ve TLS'teki site adına (SNI) bakılarak yapıldığı için bu ikisi engeli aşar. QUIC engellenir ki tarayıcı TCP'ye düşsün.
- `config/warp-*.template.json` — Cloudflare WARP'a WireGuard tüneli. Kurulumda kişisel anahtarlarınızla `data/` içine kopyalanır.
- `data/` klasörü kişisel WARP anahtarlarınızı içerir; **paylaşmayın** (git'e de eklenmez).
