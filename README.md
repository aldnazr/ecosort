# EcoSort

Aplikasi Flutter untuk klasifikasi sampah lewat kamera atau foto galeri, berjalan luring (offline) di perangkat. Model deteksi object YOLO dijalankan dengan TFLite melalui `flutter_litert`, jadi tidak ada server yang terlibat.

## Fitur

- Deteksi langsung lewat kamera: bounding box dan daftar objek diperbarui selama pratinjau.
- Klasifikasi foto dari galeri, dengan hasil ditampilkan di layar terpisah.
- Tiga kategori sampah: Organik, Kertas, Plastik.
- Delapan kelas objek: Apel, Pisang, Karton Susu, Wadah Kertas, Gulungan Kertas, Kantong Plastik, Botol Plastik, Wadah Plastik.
- Semua pemrosesan berjalan di perangkat.

## Model

| Item | Nilai |
|------|-------|
| Berkas | `lib/services/tflite/best_int8.tflite` (format int8) |
| Input | `1 x 320 x 320 x 3`, nilai RGB ternormalisasi 0..1 |
| Output | `[1, 12, 2100]` |
| Ambang skor | 0.30 |
| Ambang IoU (NMS) | 0.40 |

Kelas dan pemetaan kategorinya ada di `lib/models/detection_result.dart` (`kSupportedWasteClasses`).

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
  main.dart                        # titik masuk, inisialisasi detector
  models/
    detection_result.dart          # hasil deteksi + daftar kelas didukung
    waste_category.dart            # enum kategori (organik, kertas, plastik)
  screens/
    home_screen.dart               # layar awal: kamera atau galeri
    camera_screen.dart             # deteksi langsung via kamera
    gallery_result_screen.dart     # hasil analisis foto galeri
  services/
    image_processor.dart           # decode, resize 320x320, konversi YUV/BGRA ke RGB
    tflite/
      waste_detector_service.dart  # bootstrap interpreter TFLite
      yolo_parser.dart             # parsing output YOLO + NMS
      best_int8.tflite             # model deteksi
  widgets/
    detection_card.dart            # kartu info satu deteksi
    detection_overlay.dart         # bounding box di atas kamera
  theme/app_theme.dart             # warna dan tema aplikasi
```

## Pengujian

```bash
flutter test
```

Tersedia di `test/`: parser YOLO, `WasteDetectorService`, `ImageProcessor`, model, layar (home, camera, gallery result), dan widget (detection card, detection overlay).

## Dependensi Utama

- `flutter_litert` (3.9.3): runtime TFLite
- `camera` (0.12.1): akses kamera
- `image_picker` (1.2.4): pemilihan foto galeri
- `image` (4.10.1): dekode dan transformasi gambar
