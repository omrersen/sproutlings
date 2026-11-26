# Sproutlings — Desktop

Godot 4.4.1 ile geliştirilen izometrik 3D çiftlik ve yaratık koleksiyon oyunu. Projenin aktif sürümü yalnızca masaüstü oyunudur. İnternet bağlantısı, Python sunucusu ve kullanıcı hesabı gerekmez.

## Başlatma
Windows: `OYNA.cmd` dosyasını aç. Godot kuruluysa `project.godot` ile de çalıştırılabilir.

## İçerik
- 6 biyom, 72 tarla kapasitesi, 7 ürün ve 16 yaratık.
- Kasa, nadirlik, shiny, evrim, yem üretimi ve envanter.
- Bina, dekorasyon, görev, ansiklopedi, mevsim ve yerel kayıt.

## V1.4 — Kaşif güncellemesi
- Üç ayrı mağara: Yosun Mağarası, Köz Ocağı ve Kristal Labirenti; farklı yerleşimler, renkler, engeller ve bağımsız yenilenen cevher damarları.
- Karakterin binalar, gölet, NPC, dekorlar ve mağara engellerine karşı konum tabanlı çarpışma kontrolü; eksen boyunca kayma ve küçük hareket adımları. Tam fizik motoru kullanılmaz.
- Shift ile koşu: %55 hız artışı, saniyede 20 dayanıklılık tüketimi, dinlenirken saniyede 13 yenilenme.
- U ile keşif günlüğü: beş kalıcı başarım, altın ve kasa ödülleri, bölge/mağara mini haritası, dayanıklılık göstergesi.
- V1.3 kayıtları korunur; eski cevher durumu ilk mağaraya aktarılır. Yeni mağaralar ve başarımlar kayıt dosyasına eklenir.

## V1.5 — Ustalık ve hazine
- Dört ustalık dalı, her biri 10 seviyeye kadar: çiftçilik, madencilik, balıkçılık ve keşif. Çiftçilik büyümeyi, balıkçılık zamanlama aralığını geliştirir; diğer dallar şimdilik ilerleme göstergesi.
- P: ustalık ve atölye paneli. Enerji iksiri, madenci tılsımı, hasat rozeti ve gezgin çantası. Üç aksesuar arasından biri kuşanılır.
- Altı biyomda birer tek kullanımlık hazine, yakınında F ile altın, kasa ve keşif XP.
- Aktif yaratıkların çiftlikte karakteri takip etmesi; isteğe bağlı. Basit yumuşak takip, tam yol bulma yok.
- Önceki yerel kayıtlarla uyumlu.
## V1.3 — Gezilebilir dünya
- WASD: kameraya göre hareket; F: yakındaki NPC, tarla veya mağara ile etkileşim; T: eski dekor taşıma modu.
- Üç NPC diyalogu; balıkçılıkta dokuz saniyelik zamanlama mini oyunu; L3 sonrası üç uygun biyomdan girilebilen ayrı mağara sahnesi ve dört yenilenen cevher damarı.
- Olta, kazma ve sulama kabı; üçer geliştirme seviyesi, kuşanma ve bakır/altın maliyeti. L: ekipman.
- Envanterde ürün, kaynak ve yem sekmeleri ve kartlı stok görünümü.
- Üç yeni sabit konumlu dekor: bahçe kemeri, kuş evi ve taş fener.
- Dört hava durumu, yağmurda otomatik sulama (hava geçişinde), aydınlatma ve yağmur parçaları.
- Özgün sentezlenmiş döngüsel melodi, açma/kapatma seçeneği.
- Paylaşılan temel mesh kaynakları, büyüme basamaklarına göre tarla görsel önbelleği, hafif grafik seçeneği.
- Mevcut kayıt yolu korunur; mağaradan çıkış konumu kaydedilir, yeniden açıldığında çiftlikte başlar. Karakter hareketi sınırlandırılmıştır ancak tam fiziksel engel çarpışması henüz yoktur.

## V1.2 — Köy, keşif ve kuluçka
- 16 yaratık: Çiçekpati, Mercansırt, Közpençe ve Aykanat dört yeni üretim türü.
- L5, iki farklı tok yetişkin, 80 G: üç yumurta yuvası, 90 sn kuluçka, 180 sn ebeveyn bekleme. Mythic üretim dışı.
- Üç kalıtsal özellik, ebeveyn seçimi ve gen başına %8 mutasyon; dört özgün ebeveyn çifti için %35 yeni tür olasılığı.
- Balıkçılık (8 sn) ve madencilik (12 sn); altı kaynak ve 100 kapasiteli ayrı kaynak çantası.
- Üç NPC, UTC gününe göre değişen tüccar fiyatları; kaynak ve depo ürünleri alış/satışı.
- L5 sonrası 90 saniyelik nadir biyom olayları; etkinlik kasası ve altın.
- Yeni 3D NPC modelleri, etkinlik işareti, işlem sesleri, düğme teması ve üç yeni yönetim sekmesi.
- N: kuluçka, K: köy. Etkinlikler yönetim panelinden açılır.
- V1 kayıtları aynı konumda korunur. Kuluçka, kaynak toplama ve etkinlik süreleri oyun açıkken ilerler.
- Balıkçılık ve madencilik zamanlayıcı tabanlıdır; NPC işlemleri panelden gerçekleştirilir. Yeni grafikler prosedürel low-poly modellerdir.

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
