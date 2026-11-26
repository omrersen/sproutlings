# Sproutlings V2.0 — Web 3D Multiplayer

Tarayıcı tabanlı 3D çiftlik ve yaratık koleksiyonu. Windows, macOS ve mobil tarayıcılar için ayrı kurulum gerekmez. WebGL desteklenmeyen tarayıcıda erişilebilir 2D tarla listesi çalışmaya devam eder. Yerel Godot V1 kaynakları geçmiş sürüm için depoda korunur; web sürümünde Godot kullanılmaz.

## Çalıştır
Python 3.11+ gerekir (yalnızca sunucu bilgisayarında).
- Windows: `WEB-OYNA.cmd` → http://127.0.0.1:8770/
- Diğer işletim sistemleri: `python3 server.py --port 8770`
- Arkadaşların için: `WEB-PAYLAS.cmd` Cloudflare Quick Tunnel ile geçici HTTPS paylaşım adresi oluşturur. Resmi cloudflared Windows AMD64 istemcisi gerekir; kurulum klasörü %LOCALAPPDATA%\SproutlingsTools. Yalnızca 8770 portundaki oyun yayınlanır. Bilgisayar ve iki süreç açık kalmalıdır. Adres her tünel yeniden başlatıldığında değişebilir. İsteyen herkes bağlantıyla hesap açabilir; parola tekrar kullanmayın. Bu bir test yayınıdır, üretim hostingi değildir.
- `WEB-KAPAT.cmd`: bu başlatıcının kaydettiği sunucu/tünel süreçlerini durdurur.
- SQLite oyuncu verileri yerelde saklanır; Git'e gönderilmez. V1 veritabanı kopyalanmaz.

## Özellikler
- CDN veya ek oyun motoru gerektirmeyen yerel WebGL 3D renderer, izometrik döndürme, zoom, tarla seçimi, 12 prosedürel yaratık silüeti, çevrim içi avatarlar ve animasyonlar.
- Ortak hesap, sunucuda doğrulanan tarla/hasat, envanter, yaratık bakım/üretim, kasa RNG/pity, pazar, takas, satış grafiği, görevler, liderlik.
- Çiftlik ziyareti ve aynı çiftlikteki ziyaretçilerin görüntülenmesi; 3 saniyelik sunucu polling ile tarla değişiklikleri diğer oyunculara yansır.
- PBKDF2 parola özeti, süreli oturum, SQLite atomik işlemler, tekrar işlem kontrolü, temel istek sınırlaması ve emanet. HTTPS tüneli yalnızca oyun hizmetini erişilebilir yapar.
- 42 günlük tema dönüşümü; günlük/haftalık görevler.

## Testler
`python test_online.py`, `python test_browser.py`, `python test_web3d.py` (son ikisi Playwright gerektirir), `node --check farm3d.js`.
GitHub Actions Linux üzerinde tarayıcı ve entegrasyon testlerini çalıştırır.

## Sınırlar
V2.0 geliştirici önizlemesi. Ortak çiftlik ziyareti salt okunur; oyuncular kendi tarlalarını düzenler. Avatar konumları temsilidir, serbest dolaşma ve WebSocket henüz yoktur. V1 yerel bina, çoklu biyom, evrim ve taşınabilir dekorasyon özellikleri web sürümüne henüz taşınmadı. Mac/Safari fiziksel cihaz testi yapılmadı. Uzun süreli performans, güvenlik denetimi ve üretim dağıtımı yapılmadı. Kalıcı ücretsiz hosting garantisi yoktur; GitHub Pages dinamik Python/SQLite sunucusunu barındırmaz.
