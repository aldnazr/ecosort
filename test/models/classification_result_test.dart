import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/classification_result.dart';

void main() {
  group('kWasteClasses', () {
    test('has the six dataset classes in notebook order', () {
      expect(kWasteClasses.length, 6);
      expect(
        kWasteClasses.map((c) => c.id).toList(),
        ['cardboard', 'glass', 'metal', 'paper', 'plastic', 'trash'],
      );
      expect(
        kWasteClasses.map((c) => c.displayName).toList(),
        ['Kardus', 'Kaca', 'Logam', 'Kertas', 'Plastik', 'Sampah lainnya'],
      );
    });
  });

  group('ClassificationResult.fromIndex', () {
    for (var i = 0; i < kWasteClasses.length; i++) {
      test('maps index $i to ${kWasteClasses[i].id}', () {
        final result = ClassificationResult.fromIndex(i, 0.5);
        expect(result.classIndex, i);
        expect(result.label, kWasteClasses[i].id);
        expect(result.displayName, kWasteClasses[i].displayName);
        expect(result.score, 0.5);
      });
    }

    test('keeps a low score as the top-1 result', () {
      final result = ClassificationResult.fromIndex(5, 0.01);
      expect(result.displayName, 'Sampah lainnya');
      expect(result.score, 0.01);
    });

    test('rejects out-of-range indices', () {
      expect(() => ClassificationResult.fromIndex(6, 0.5), throwsRangeError);
      expect(() => ClassificationResult.fromIndex(-1, 0.5), throwsRangeError);
    });
  });

  group('ClassificationResult equality', () {
    test('equal index and score are equal regardless of construction', () {
      final a = ClassificationResult.fromIndex(2, 0.75);
      const b = ClassificationResult(
        classIndex: 2,
        label: 'metal',
        displayName: 'Logam',
        score: 0.75,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different score is not equal', () {
      final a = ClassificationResult.fromIndex(2, 0.75);
      final b = ClassificationResult.fromIndex(2, 0.76);
      expect(a, isNot(equals(b)));
    });
  });
}