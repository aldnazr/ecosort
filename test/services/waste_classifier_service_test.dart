import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/classification_result.dart';
import 'package:ecosort/services/tflite/waste_classifier_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pickTopIndex', () {
    test('returns the argmax', () {
      final probs = Float32List.fromList([0.1, 0.2, 0.3, 0.25, 0.1, 0.05]);
      expect(pickTopIndex(probs), 2);
    });

    test('ties pick the first index deterministically', () {
      final probs = Float32List.fromList([0.2, 0.5, 0.5, 0.1, 0.0, 0.0]);
      expect(pickTopIndex(probs), 1);
    });

    test('all equal picks index 0', () {
      final probs = Float32List.fromList([0.2, 0.2, 0.2, 0.2, 0.1, 0.1]);
      expect(pickTopIndex(probs), 0);
    });
  });

  group('validateProbabilities', () {
    test('accepts a valid softmax output', () {
      final probs = Float32List.fromList([0.5, 0.2, 0.1, 0.1, 0.05, 0.05]);
      validateProbabilities(probs);
    });

    test('rejects wrong length', () {
      final probs = Float32List.fromList([0.5, 0.5, 0.0, 0.0, 0.0]);
      expect(() => validateProbabilities(probs), throwsStateError);
    });

    test('rejects NaN and Infinity', () {
      final nan = Float32List.fromList([double.nan, 0.2, 0.2, 0.2, 0.2, 0.2]);
      expect(() => validateProbabilities(nan), throwsStateError);

      final inf =
          Float32List.fromList([double.infinity, 0.2, 0.2, 0.2, 0.2, 0.2]);
      expect(() => validateProbabilities(inf), throwsStateError);
    });

    test('rejects values outside 0..1', () {
      final probs = Float32List.fromList([1.5, 0.2, 0.2, 0.2, 0.2, -0.3]);
      expect(() => validateProbabilities(probs), throwsStateError);
    });

    test('rejects sums far from 1', () {
      final probs = Float32List.fromList([0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
      expect(() => validateProbabilities(probs), throwsStateError);
    });
  });

  group('validateModelInput', () {
    test('accepts 0..255 float values', () {
      final input = Float32List(2 * 2 * 3);
      for (var i = 0; i < input.length; i++) {
        input[i] = (i * 40) % 256.0;
      }
      input[input.length - 1] = 255.0;
      validateModelInput(input, expectedLength: input.length);
    });

    test('rejects wrong length', () {
      expect(
        () => validateModelInput(Float32List(10), expectedLength: 12),
        throwsArgumentError,
      );
    });

    test('rejects NaN, Infinity and out-of-range values', () {
      final nan = Float32List(3)..[1] = double.nan;
      expect(
        () => validateModelInput(nan, expectedLength: 3),
        throwsArgumentError,
      );

      final inf = Float32List(3)..[1] = double.infinity;
      expect(
        () => validateModelInput(inf, expectedLength: 3),
        throwsArgumentError,
      );

      final over = Float32List(3)..[1] = 300.0;
      expect(
        () => validateModelInput(over, expectedLength: 3),
        throwsArgumentError,
      );

      final negative = Float32List(3)..[1] = -0.5;
      expect(
        () => validateModelInput(negative, expectedLength: 3),
        throwsArgumentError,
      );
    });
  });

  group('WasteClassifierService (real model binary)', () {
    late WasteClassifierService classifier;

    setUp(() {
      classifier = WasteClassifierService();
    });

    tearDown(() {
      classifier.dispose();
    });

    test('initialize validates the model contract', () async {
      await classifier.initialize();
      expect(classifier.isInitialized, isTrue);
      expect(classifier.inputShape, [1, 224, 224, 3]);
      expect(classifier.inputWidth, 224);
      expect(classifier.inputHeight, 224);
    });

    test('initialize is idempotent for concurrent callers', () async {
      await Future.wait([
        classifier.initialize(),
        classifier.initialize(),
        classifier.initialize(),
      ]);
      expect(classifier.isInitialized, isTrue);
    });

    test('classify returns a valid top-1 result', () async {
      await classifier.initialize();

      final input = Float32List(224 * 224 * 3);
      input.fillRange(0, input.length, 128.0);
      final result = await classifier.classify(input);

      expect(result, isA<ClassificationResult>());
      expect(result.classIndex, inInclusiveRange(0, 5));
      expect(result.label, kWasteClasses[result.classIndex].id);
      expect(result.displayName, kWasteClasses[result.classIndex].displayName);
      expect(result.score, inInclusiveRange(0.0, 1.0));
    });

    test('concurrent classify calls all produce valid results', () async {
      await classifier.initialize();

      final input = Float32List(224 * 224 * 3)..fillRange(0, 224 * 224 * 3, 100.0);
      final results = await Future.wait([
        classifier.classify(input),
        classifier.classify(input),
        classifier.classify(input),
      ]);

      for (final result in results) {
        expect(result.classIndex, inInclusiveRange(0, 5));
        expect(result.score, inInclusiveRange(0.0, 1.0));
      }
    });

    test('classify before initialization throws StateError', () async {
      final input = Float32List(224 * 224 * 3);
      expect(() => classifier.classify(input), throwsStateError);
    });

    test('classify rejects wrong input length', () async {
      await classifier.initialize();
      expect(
        () => classifier.classify(Float32List(100)),
        throwsArgumentError,
      );
    });

    test('classify rejects NaN input', () async {
      await classifier.initialize();
      final input = Float32List(224 * 224 * 3)..[0] = double.nan;
      expect(() => classifier.classify(input), throwsArgumentError);
    });

    test('classify rejects out-of-range input', () async {
      await classifier.initialize();
      final input = Float32List(224 * 224 * 3)..[0] = 300.0;
      expect(() => classifier.classify(input), throwsArgumentError);
    });

    test('garbage model bytes fail initialization with a clear error', () async {
      final broken = WasteClassifierService(modelBytes: Uint8List.fromList([1, 2, 3]));
      expect(broken.initialize(), throwsStateError);
      // Allow a retry attempt after failure.
      await expectLater(broken.initialize(), throwsStateError);
      broken.dispose();
    });

    test('double dispose is safe', () async {
      await classifier.initialize();
      classifier.dispose();
      classifier.dispose();
      expect(classifier.isInitialized, isFalse);
    });

    test('dispose before initialization is safe', () {
      final unused = WasteClassifierService();
      unused.dispose();
      expect(unused.isInitialized, isFalse);
    });

    test('classify after dispose throws', () async {
      await classifier.initialize();
      final input = Float32List(224 * 224 * 3);
      final result = await classifier.classify(input);
      expect(result.classIndex, inInclusiveRange(0, 5));
      classifier.dispose();
      expect(() => classifier.classify(input), throwsStateError);
    });
  });
}