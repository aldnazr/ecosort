import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/detection_result.dart';
import 'package:ecosort/models/waste_category.dart';
import 'package:ecosort/widgets/detection_card.dart';

void main() {
  testWidgets('DetectionCard displays object details properly', (tester) async {
    const detection = DetectionResult(
      normalizedRect: Rect.fromLTWH(0.1, 0.1, 0.5, 0.5),
      classIndex: 6,
      label: 'plastic_bottle',
      displayName: 'Botol Plastik',
      category: WasteCategory.plastik,
      score: 0.92,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DetectionCard(detection: detection),
        ),
      ),
    );

    expect(find.text('Botol Plastik'), findsOneWidget);
    expect(find.text('Plastik'), findsOneWidget);
    expect(find.text('Keyakinan: 92%'), findsOneWidget);
  });
}
