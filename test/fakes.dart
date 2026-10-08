import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/models/classification_result.dart';
import 'package:ecosort/services/tflite/waste_classifier_service.dart';

class FakeClassifier implements WasteClassifier {
  bool _initialized = false;
  ClassificationResult nextResult = ClassificationResult.fromIndex(0, 0.9);
  Object? classifyThrows;
  Object? initError;
  int classifyCalls = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    if (initError != null) {
      throw initError!;
    }
    _initialized = true;
  }

  @override
  Future<ClassificationResult> classify(Float32List rgbInput) async {
    classifyCalls++;
    final error = classifyThrows;
    if (error != null) {
      throw error;
    }
    return nextResult;
  }

  @override
  void dispose() {
    _initialized = false;
  }
}