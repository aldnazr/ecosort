import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/screens/camera_screen.dart';
import 'package:ecosort/theme/app_theme.dart';
import '../fakes.dart';

void main() {
  testWidgets('CameraScreen displays error when no cameras are found', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: CameraScreen(
          classifier: FakeClassifier(),
          availableCameras: const [],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Klasifikasi Langsung'), findsOneWidget);
    expect(find.text('Tidak ada sensor kamera yang ditemukan pada perangkat.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
  });

  testWidgets('model load failure shows recovery UI instead of live view', (
    tester,
  ) async {
    final classifier = FakeClassifier()
      ..initError = StateError('model incompatible');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: CameraScreen(
          classifier: classifier,
          availableCameras: const [],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Model klasifikasi gagal dimuat'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });
}