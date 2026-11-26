# Sproutlings — Desktop

Godot 4.4.1 ile geliştirilen izometrik 3D çiftlik ve yaratık koleksiyon oyunu. Projenin aktif sürümü yalnızca masaüstü oyunudur. İnternet bağlantısı, Python sunucusu ve kullanıcı hesabı gerekmez.

## Başlatma
Windows: `OYNA.cmd` dosyasını aç. Godot kuruluysa `project.godot` ile de çalıştırılabilir.

## İçerik
- 6 biyom, 72 tarla kapasitesi, 7 ürün ve 12 yaratık.
- Kasa, nadirlik, shiny, evrim, yem üretimi ve envanter.
- Bina, dekorasyon, görev, ansiklopedi, mevsim ve yerel kayıt.

## V1.1 — Gelişim güncellemesi
- Ürün bazlı tekrar edilebilir hasat sözleşmeleri ve ödüller.
- Üç araştırma dalı, her birinde beş kademe: büyüme, hasat ve eğitim.
- Tok yaratıklar için altın karşılığında eğitim; ilk beslemede gelişim bonusu.
- Hazır ürünleri H ile topluca hasat etme; J ile gelişim paneli.
- İsteğe bağlı, en fazla iki saat çevrim dışı sulanmış ürün büyümesi. Ödüller ancak oyuncu hasat ettiğinde verilir.
- V1.0 kayıtları aynı konumda korunur; yeni alanlar yedekli kayda eklenir.

## Kontroller
Fare: tarla seç; Space: ek/sula/hasat; Q/E: kamera; I: envanter; M: yönetim; B: dekor; D: taşı; F1: rehber; F11: tam ekran.

## Test
`godot --headless --path . -- --self-test`
`godot --path . -- --visual-test`

Geliştirici önizlemesi. Grafikler prosedürel low-poly; geniş ölçekli performans ve denge testi yapılmamıştır.
