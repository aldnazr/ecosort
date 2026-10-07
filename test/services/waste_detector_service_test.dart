import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/services/tflite/waste_detector_service.dart';

void main() {
  group('WasteDetectorService', () {
    test('initializes and runs detection on raw model bytes', () async {
      final modelBytes = File('lib/services/tflite/best_int8.tflite').readAsBytesSync();
      final detector = WasteDetectorService(modelBytes: modelBytes);

      expect(detector.isInitialized, isFalse);
      await detector.initialize();
      expect(detector.isInitialized, isTrue);
      expect(detector.inputWidth, 320);
      expect(detector.inputHeight, 320);
      expect(detector.inputShape, [1, 320, 320, 3]);

      // Run with dummy input
      final dummyInput = Float32List(1 * 320 * 320 * 3);
      final results = await detector.detect(dummyInput);
      expect(results, isA<List>());

      detector.dispose();
      expect(detector.isInitialized, isFalse);
    });

    test('throws StateError when detecting before initialization', () async {
      final detector = WasteDetectorService(
        modelBytes: File('lib/services/tflite/best_int8.tflite').readAsBytesSync(),
      );

      final dummyInput = Float32List(1 * 320 * 320 * 3);
      expect(() => detector.detect(dummyInput), throwsStateError);
    });

    test('throws ArgumentError when input length is incorrect', () async {
      final modelBytes = File('lib/services/tflite/best_int8.tflite').readAsBytesSync();
      final detector = WasteDetectorService(modelBytes: modelBytes);
      await detector.initialize();

      final badInput = Float32List(100);
      expect(() => detector.detect(badInput), throwsArgumentError);

      detector.dispose();
    });
  });
}
