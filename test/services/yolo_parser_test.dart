import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/detection_result.dart';
import 'package:ecosort/models/waste_category.dart';
import 'package:ecosort/services/tflite/yolo_parser.dart';

void main() {
  group('YoloParser', () {
    test('calculateIoU returns correct values', () {
      // Identical boxes -> IoU = 1.0
      const r1 = Rect.fromLTWH(0.1, 0.1, 0.2, 0.2);
      const r2 = Rect.fromLTWH(0.1, 0.1, 0.2, 0.2);
      expect(YoloParser.calculateIoU(r1, r2), closeTo(1.0, 0.001));

      // Disjoint boxes -> IoU = 0.0
      const r3 = Rect.fromLTWH(0.5, 0.5, 0.2, 0.2);
      expect(YoloParser.calculateIoU(r1, r3), 0.0);

      // 50% overlap box
      const r4 = Rect.fromLTWH(0.1, 0.1, 0.2, 0.1);
      expect(YoloParser.calculateIoU(r1, r4), closeTo(0.5, 0.001));
    });

    test('parseOutput with [1, 12, N] channels-first format', () {
      const int numAnchors = 3;
      final List<double> raw = List.filled(12 * numAnchors, 0.0);

      // Anchor 0: cx=0.5, cy=0.5, w=0.2, h=0.2, class 0 (apple) score=0.85
      raw[0 * numAnchors + 0] = 0.5;
      raw[1 * numAnchors + 0] = 0.5;
      raw[2 * numAnchors + 0] = 0.2;
      raw[3 * numAnchors + 0] = 0.2;
      raw[4 * numAnchors + 0] = 0.85;

      // Anchor 1: below threshold score=0.20
      raw[0 * numAnchors + 1] = 0.3;
      raw[1 * numAnchors + 1] = 0.3;
      raw[2 * numAnchors + 1] = 0.1;
      raw[3 * numAnchors + 1] = 0.1;
      raw[5 * numAnchors + 1] = 0.20;

      // Anchor 2: cx=0.8, cy=0.8, w=0.15, h=0.15, class 6 (plastic_bottle) score=0.92
      raw[0 * numAnchors + 2] = 0.8;
      raw[1 * numAnchors + 2] = 0.8;
      raw[2 * numAnchors + 2] = 0.15;
      raw[3 * numAnchors + 2] = 0.15;
      raw[(4 + 6) * numAnchors + 2] = 0.92;

      final results = YoloParser.parseOutput(
        rawOutput: raw,
        shape: [1, 12, numAnchors],
        scoreThreshold: 0.30,
        iouThreshold: 0.40,
      );

      expect(results.length, 2);
      expect(results[0].label, 'plastic_bottle');
      expect(results[0].displayName, 'Botol Plastik');
      expect(results[0].category, WasteCategory.plastik);
      expect(results[0].score, closeTo(0.92, 0.001));

      expect(results[1].label, 'apple');
      expect(results[1].displayName, 'Apel');
      expect(results[1].category, WasteCategory.organik);
      expect(results[1].score, closeTo(0.85, 0.001));
    });

    test('parseOutput with [1, N, 12] channels-last format', () {
      const int numAnchors = 2;
      final List<double> raw = List.filled(numAnchors * 12, 0.0);

      // Anchor 0: cx=0.4, cy=0.4, w=0.2, h=0.2, class 1 (banana) score=0.75
      raw[0 * 12 + 0] = 0.4;
      raw[0 * 12 + 1] = 0.4;
      raw[0 * 12 + 2] = 0.2;
      raw[0 * 12 + 3] = 0.2;
      raw[0 * 12 + 4 + 1] = 0.75;

      // Anchor 1: cx=0.7, cy=0.7, w=0.2, h=0.2, class 2 (milk_carton) score=0.65
      raw[1 * 12 + 0] = 0.7;
      raw[1 * 12 + 1] = 0.7;
      raw[1 * 12 + 2] = 0.2;
      raw[1 * 12 + 3] = 0.2;
      raw[1 * 12 + 4 + 2] = 0.65;

      final results = YoloParser.parseOutput(
        rawOutput: raw,
        shape: [1, numAnchors, 12],
        scoreThreshold: 0.30,
        iouThreshold: 0.40,
      );

      expect(results.length, 2);
      expect(results[0].label, 'banana');
      expect(results[0].category, WasteCategory.organik);
      expect(results[1].label, 'milk_carton');
      expect(results[1].category, WasteCategory.kertas);
    });

    test('NMS suppresses overlapping boxes of the same class', () {
      const d1 = DetectionResult(
        normalizedRect: Rect.fromLTWH(0.1, 0.1, 0.3, 0.3),
        classIndex: 0,
        label: 'apple',
        displayName: 'Apel',
        category: WasteCategory.organik,
        score: 0.90,
      );

      // Heavily overlapping same class with lower score -> suppressed
      const d2 = DetectionResult(
        normalizedRect: Rect.fromLTWH(0.11, 0.11, 0.29, 0.29),
        classIndex: 0,
        label: 'apple',
        displayName: 'Apel',
        category: WasteCategory.organik,
        score: 0.70,
      );

      // Overlapping but DIFFERENT class -> NOT suppressed
      const d3 = DetectionResult(
        normalizedRect: Rect.fromLTWH(0.11, 0.11, 0.29, 0.29),
        classIndex: 5,
        label: 'plastic_bag',
        displayName: 'Kantong Plastik',
        category: WasteCategory.plastik,
        score: 0.80,
      );

      final selected = YoloParser.applyNms([d1, d2, d3], iouThreshold: 0.40);
      expect(selected.length, 2);
      expect(selected.map((d) => d.label), containsAll(['apple', 'plastic_bag']));
    });

    test('ignores NaN and Inf values gracefully', () {
      final List<double> raw = List.filled(12 * 1, 0.0);
      raw[0] = double.nan;
      raw[1] = 0.5;
      raw[2] = 0.2;
      raw[3] = 0.2;
      raw[4] = 0.99;

      final results = YoloParser.parseOutput(
        rawOutput: raw,
        shape: [1, 12, 1],
      );

      expect(results, isEmpty);
    });
  });
}
