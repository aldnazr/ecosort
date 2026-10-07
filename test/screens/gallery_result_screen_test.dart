import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/detection_result.dart';
import 'package:ecosort/models/waste_category.dart';
import 'package:ecosort/screens/gallery_result_screen.dart';
import 'package:ecosort/theme/app_theme.dart';
import 'package:image/image.dart' as img;
import 'home_screen_test.dart';

void main() {
  late Uint8List testImageBytes;

  setUpAll(() {
    final image = img.Image(width: 100, height: 100);
    testImageBytes = Uint8List.fromList(img.encodePng(image));
  });

  testWidgets('GalleryResultScreen displays detected objects and buttons', (tester) async {
    final mockDetector = MockWasteDetector();

    const detection = DetectionResult(
      normalizedRect: Rect.fromLTWH(0.1, 0.1, 0.4, 0.4),
      classIndex: 1,
      label: 'banana',
      displayName: 'Pisang',
      category: WasteCategory.organik,
      score: 0.94,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: GalleryResultScreen(
          initialImageBytes: testImageBytes,
          initialDetections: const [detection],
          detector: mockDetector,
        ),
      ),
    );

    expect(find.text('Hasil Analisis Foto'), findsOneWidget);
    expect(find.text('Objek Terdeteksi'), findsOneWidget);
    expect(find.text('1 objek'), findsOneWidget);
    expect(find.text('Pisang'), findsOneWidget);
    expect(find.text('Pilih Foto Lain'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
  });

  testWidgets('GalleryResultScreen displays empty state when no objects recognized', (tester) async {
    final mockDetector = MockWasteDetector();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: GalleryResultScreen(
          initialImageBytes: testImageBytes,
          initialDetections: const [],
          detector: mockDetector,
        ),
      ),
    );

    expect(find.text('Belum ada objek yang dikenali'), findsOneWidget);
    expect(find.text('0 objek'), findsOneWidget);
  });
}
