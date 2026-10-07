import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/screens/camera_screen.dart';
import 'package:ecosort/theme/app_theme.dart';
import 'home_screen_test.dart';

void main() {
  testWidgets('CameraScreen displays error when no cameras are found', (tester) async {
    final mockDetector = MockWasteDetector();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: CameraScreen(
          detector: mockDetector,
          availableCameras: const [],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Deteksi Langsung'), findsOneWidget);
    expect(find.text('Tidak ada sensor kamera yang ditemukan pada perangkat.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
  });
}
