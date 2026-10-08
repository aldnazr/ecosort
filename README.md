# EcoSort

Aplikasi Flutter untuk klasifikasi sampah lewat kamera atau foto galeri, berjalan luring (offline) di perangkat. Model klasifikasi MobileNetV4-Small dijalankan dengan LiteRT melalui `flutter_litert`, jadi tidak ada server yang terlibat.

## Fitur

- Klasifikasi langsung lewat kamera: kelas teratas (top-1) beserta skor model diperbarui selama pratinjau.
- Klasifikasi foto dari galeri, dengan hasil ditampilkan di layar terpisah.
- Enam kelas: Kardus, Kaca, Logam, Kertas, Plastik, Sampah lainnya.
- Semua pemrosesan berjalan di perangkat.

Skor model adalah probabilitas softmax dari model, bukan ukuran akurasi terukur, dan model tidak menjamin pengenalan benda di luar enam kelas. Isi foto dengan satu jenis sampah agar hasil lebih akurat.

## Model

| Item | Nilai |
|------|-------|
| Berkas | `lib/services/tflite/garbage_mobilenetv4_small.tflite` |
| Input | `1 x 224 x 224 x 3`, float32 NHWC RGB, nilai piksel 0..255 |
| Preprocessing | Resize bilinear langsung seluruh gambar ke 224x224, tanpa crop/letterbox; tanpa normalisasi di aplikasi (mean/std sudah ditanam di model) |
| Output | `1 x 6`, float32, probabilitas softmax |
| Indeks | 0 cardboard, 1 glass, 2 metal, 3 paper, 4 plastic, 5 trash |
| Hasil | Argmax (tie memakai indeks pertama) beserta probabilitasnya; tanpa ambang skor |

Sumber kontrak: `lib/services/tflite/Garbage_Classification_MobileNetV4_Small_TFLite.ipynb`. Pemetaan tampilan ada di `lib/models/classification_result.dart` (`kWasteClasses`).

## Persyaratan

- Dart SDK `^3.14.0-211.1.beta` (lihat `pubspec.yaml`)
- Flutter dengan dukungan platform Android
- Izin kamera (sudah dideklarasikan di `AndroidManifest.xml`)

## Menjalankan

```bash
flutter pub get
flutter run
```

## Struktur Proyek

```
lib/
  main.dart                        # titik masuk, inisialisasi classifier
  models/
    classification_result.dart     # hasil klasifikasi + daftar enam kelas
  screens/
    home_screen.dart               # layar awal: kamera atau galeri
    camera_screen.dart             # klasifikasi langsung via kamera
    gallery_result_screen.dart     # hasil analisis foto galeri
  services/
    image_processor.dart           # decode+EXIF, konversi YUV/BGRA, resize 224x224, packing 0..255
    tflite/
      waste_classifier_service.dart  # bootstrap interpreter LiteRT, argmax, validasi output
      garbage_mobilenetv4_small.tflite # model klasifikasi
  widgets/
    classification_card.dart       # kartu satu hasil (label + skor model)
  theme/app_theme.dart             # warna dan tema aplikasi
```

## Pengujian

```bash
flutter test
```

Tersedia di `test/`: model (`classification_result`), `WasteClassifierService` termasuk smoke test model asli, `ImageProcessor` (RGB 0..255, resize tanpa crop, rotasi, stride kamera, EXIF), layar (home, camera, gallery result), dan widget (`classification_card`).

## Dependensi Utama

- `flutter_litert` (3.9.3): runtime LiteRT
- `camera` (0.12.1): akses kamera
- `image_picker` (1.2.4): pemilihan foto galeri
- `image` (4.10.1): dekode dan transformasi gambar