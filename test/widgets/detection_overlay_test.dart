import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/detection_result.dart';
import 'package:ecosort/models/waste_category.dart';
import 'package:ecosort/widgets/detection_overlay.dart';

void main() {
  testWidgets('DetectionOverlayPainter paints without throwing', (tester) async {
    const detection = DetectionResult(
      normalizedRect: Rect.fromLTWH(0.2, 0.2, 0.4, 0.4),
      classIndex: 0,
      label: 'apple',
      displayName: 'Apel',
      category: WasteCategory.organik,
      score: 0.88,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: CustomPaint(
              painter: DetectionOverlayPainter(
                detections: const [detection],
                previewSize: const Size(400, 400),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
  });
}
