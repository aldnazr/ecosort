import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/detection_result.dart';
import 'package:ecosort/models/waste_category.dart';

void main() {
  group('WasteCategory', () {
    test('has correct category labels', () {
      expect(WasteCategory.organik.label, 'Organik');
      expect(WasteCategory.kertas.label, 'Kertas');
      expect(WasteCategory.plastik.label, 'Plastik');
    });
  });

  group('kSupportedWasteClasses', () {
    test('contains exact 8 waste classes with correct categories', () {
      expect(kSupportedWasteClasses.length, 8);

      expect(kSupportedWasteClasses[0].id, 'apple');
      expect(kSupportedWasteClasses[0].displayName, 'Apel');
      expect(kSupportedWasteClasses[0].category, WasteCategory.organik);

      expect(kSupportedWasteClasses[1].id, 'banana');
      expect(kSupportedWasteClasses[1].displayName, 'Pisang');
      expect(kSupportedWasteClasses[1].category, WasteCategory.organik);

      expect(kSupportedWasteClasses[2].id, 'milk_carton');
      expect(kSupportedWasteClasses[2].displayName, 'Karton Susu');
      expect(kSupportedWasteClasses[2].category, WasteCategory.kertas);

      expect(kSupportedWasteClasses[3].id, 'paper_container');
      expect(kSupportedWasteClasses[3].displayName, 'Wadah Kertas');
      expect(kSupportedWasteClasses[3].category, WasteCategory.kertas);

      expect(kSupportedWasteClasses[4].id, 'paper_roll');
      expect(kSupportedWasteClasses[4].displayName, 'Gulungan Kertas');
      expect(kSupportedWasteClasses[4].category, WasteCategory.kertas);

      expect(kSupportedWasteClasses[5].id, 'plastic_bag');
      expect(kSupportedWasteClasses[5].displayName, 'Kantong Plastik');
      expect(kSupportedWasteClasses[5].category, WasteCategory.plastik);

      expect(kSupportedWasteClasses[6].id, 'plastic_bottle');
      expect(kSupportedWasteClasses[6].displayName, 'Botol Plastik');
      expect(kSupportedWasteClasses[6].category, WasteCategory.plastik);

      expect(kSupportedWasteClasses[7].id, 'plastic_container');
      expect(kSupportedWasteClasses[7].displayName, 'Wadah Plastik');
      expect(kSupportedWasteClasses[7].category, WasteCategory.plastik);
    });
  });

  group('DetectionResult', () {
    test('equality and hashcode works', () {
      const d1 = DetectionResult(
        normalizedRect: Rect.fromLTWH(0.1, 0.1, 0.3, 0.3),
        classIndex: 0,
        label: 'apple',
        displayName: 'Apel',
        category: WasteCategory.organik,
        score: 0.95,
      );

      const d2 = DetectionResult(
        normalizedRect: Rect.fromLTWH(0.1, 0.1, 0.3, 0.3),
        classIndex: 0,
        label: 'apple',
        displayName: 'Apel',
        category: WasteCategory.organik,
        score: 0.95,
      );

      const d3 = DetectionResult(
        normalizedRect: Rect.fromLTWH(0.2, 0.2, 0.3, 0.3),
        classIndex: 1,
        label: 'banana',
        displayName: 'Pisang',
        category: WasteCategory.organik,
        score: 0.85,
      );

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1, isNot(equals(d3)));
      expect(d1.toString(), contains('Apel'));
      expect(d1.toString(), contains('95.0%'));
    });
  });
}
