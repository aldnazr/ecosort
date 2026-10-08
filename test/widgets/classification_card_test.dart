import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/classification_result.dart';
import 'package:ecosort/widgets/classification_card.dart';

void main() {
  testWidgets('ClassificationCard shows one label and model score', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClassificationCard(
            result: ClassificationResult(
              classIndex: 2,
              label: 'metal',
              displayName: 'Logam',
              score: 0.73,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Logam'), findsOneWidget);
    expect(find.text('Skor model: 73%'), findsOneWidget);
    // No duplicated category badge and no "Keyakinan"/"akurasi" wording.
    expect(find.text('Keyakinan'), findsNothing);
    expect(find.text('Akurasi'), findsNothing);
  });

  testWidgets('ClassificationCard rounds low scores to zero percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClassificationCard(
            result: ClassificationResult(
              classIndex: 5,
              label: 'trash',
              displayName: 'Sampah lainnya',
              score: 0.004,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sampah lainnya'), findsOneWidget);
    expect(find.text('Skor model: 0%'), findsOneWidget);
  });
}