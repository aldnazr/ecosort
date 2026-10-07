import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/detection_result.dart';
import 'package:ecosort/screens/home_screen.dart';
import 'package:ecosort/services/tflite/waste_detector_service.dart';
import 'package:ecosort/theme/app_theme.dart';

class MockWasteDetector implements WasteDetector {
  bool _initialized = false;
  List<DetectionResult> nextResults = [];

  @override
  bool get isInitialized => _initialized;

  @override
  List<int> get inputShape => [1, 320, 320, 3];

  @override
  int get inputWidth => 320;

  @override
  int get inputHeight => 320;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<List<DetectionResult>> detect(Float32List rgbNormalizedInput) async {
    return nextResults;
  }

  @override
  void dispose() {
    _initialized = false;
  }
}

void main() {
  testWidgets('HomeScreen renders title, categories, and action buttons', (tester) async {
    final mockDetector = MockWasteDetector();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: HomeScreen(detector: mockDetector),
      ),
    );

    expect(find.text('EcoSort'), findsOneWidget);
    expect(find.text('Kategori Sampah Didukung'), findsOneWidget);
    expect(find.text('Organik'), findsOneWidget);
    expect(find.text('Kertas'), findsOneWidget);
    expect(find.text('Plastik'), findsOneWidget);
    expect(find.text('Mulai Kamera'), findsOneWidget);
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
  });
}
