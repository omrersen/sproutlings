# Sproutlings V1.0
**Çiftlik simülasyonu + yaratık koleksiyonu + oyuncu ekonomisi.**

Sproutlings, Godot 4 ile oluşturulmuş yerel izometrik low-poly 3D çiftlik ve Python/SQLite tabanlı ayrı sunucu-yetkili çevrim içi web çiftliği içeren geliştirme sürümüdür.

## Kurulum ve çalıştırma (Windows)
- Godot 4.4.1 (veya uyumlu Godot 4 sürümü) ve Python 3.11+ kurulu olmalıdır.
- `OYNA.cmd`: yerel sunucuyu başlatır ve 3D oyunu açar. Motor bulunamazsa Godot Project Manager üzerinden project.godot açılabilir.
- `ONLINE.cmd`: yerel sunucuyu başlatır ve çevrim içi çiftliği tarayıcıda açar.
- `SUNUCU.cmd`: sunucuyu ön planda çalıştırır.
- Alternatif: `python server.py`, ardından http://127.0.0.1:8769/
- Yerel 3D modun verileri ve çevrim içi hesap verileri birbirinden ayrıdır. Çevrim içi moda geçiş oyundaki düğme ile mümkündür, ancak çevrim içi arayüz tarayıcıdadır.

## 3D yerel oyun
- 6 biyom, 72 tarla kapasitesi, 7 ürün, 12 özgün prosedürel yaratık, 6 kasa, shiny ve pity.
- Binalar, depolama, yem ve işleme tarifleri, evrim, görevler, ansiklopedi, dekorasyon sürükle-bırak ve 4 mevsim.
- Rehber, grafik/ses/hareket ayarları, tam ekran, ayrı V1 kayıt ve yedekli kayıt değiştirme.
- Fare: tarla seç; Space: ek/sula/hasat; Q/E kamera; I envanter; M yönetim; B dekor; D dekor taşı; F1 rehber; F11 tam ekran.

## Sunucu-yetkili çevrim içi mod
- Kayıt/giriş, PBKDF2-HMAC-SHA256 şifre özeti, rastgele süreli oturumlar.
- Sunucuda altın, ekim/sulama/hasat zamanlaması, seviye, kasa kazanma, güvenli RNG ve pity, yaratık sahipliği, envanter/yem üretimi ve bakım.
- Pazar: yaratık ve malzeme/yem ilanı, emanet, %5 vergi, süre sonu/iptal ve geçmiş fiyat grafiği.
- Takas: değiştirilemeyen teklif, gönderenin emanet varlığı, karşı tarafın kesin onayı ve SQLite atomik transferi.
- Liderlik, salt-okunur ziyaret, günlük/haftalık görev, 42 günlük dönüşümlü festival temaları.
- Tekrarlanan işlem kimliğiyle çift ödülü önleme, temel istek sınırı, işlem kaydı ve SQLite bütünlük kontrolleri.

## Test
```sh
python test_online.py
python test_browser.py
godot --headless --path . -- --self-test
godot --path . -- --visual-test
```
Tarayıcı testi için Playwright ve Edge/Chromium gerekir: `pip install playwright`. Alternatif tarayıcı: `python -m playwright install chromium`. Testler geçici veritabanı kullanır. Sunucu çalışma zamanı yalnızca Python standart kütüphanesini gerektirir.

## Bilinen sınırlar
V1.0 geliştirici önizlemesidir, üretimde yayınlanmış MMO değildir. 3D mod ve çevrim içi web modu henüz aynı çiftliği eşzamanlı göstermez; 3D çok oyunculu gezinti yoktur. Çevrim içi ziyaretler web arayüzünde salt okunurdur. Festival temaları aynı görev mekanizmasını kullanır. Çevrim içi çiftlik ekonomisinin kuralları yerel 3D moddan bazı farklılıklar içerir. Grafikler prosedürel; profesyonel modelleme, geniş ölçekli performans/denge ve güvenlik denetimi yapılmadı. Sunucu sadece loopback (127.0.0.1) üzerinde çalışır; internet yayını için TLS, üretim kimlik doğrulama/operasyonel sertleştirme, yedekleme ve daha geniş test gerekir. Veritabanı ve kayıtlar Git'e dahil edilmez.
