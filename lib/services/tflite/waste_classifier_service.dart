import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';

import '../../models/classification_result.dart';

abstract class WasteClassifier {
  bool get isInitialized;

  Future<void> initialize();

  Future<ClassificationResult> classify(Float32List rgbInput);

  void dispose();
}

/// Argmax with deterministic ties: the first highest index wins.
int pickTopIndex(Float32List probabilities) {
  var best = 0;
  for (var i = 1; i < probabilities.length; i++) {
    if (probabilities[i] > probabilities[best]) best = i;
  }
  return best;
}

/// Model outputs are post-softmax probabilities. Corrupted output becomes an
/// error instead of a fabricated label.
void validateProbabilities(Float32List probabilities) {
  const tolerance = 1e-3;
  if (probabilities.length != kWasteClasses.length) {
    throw StateError(
      'Model output length mismatch: expected ${kWasteClasses.length} '
      'probabilities, got ${probabilities.length}.',
    );
  }
  for (final p in probabilities) {
    if (p.isNaN || p.isInfinite) {
      throw StateError('Model output contains NaN or Infinity.');
    }
    if (p < -tolerance || p > 1 + tolerance) {
      throw StateError(
        'Model output is not a probability: found $p outside 0..1.',
      );
    }
  }
  final sum = probabilities.reduce((a, b) => a + b);
  if ((sum - 1).abs() > 0.01) {
    throw StateError('Model output does not sum to 1 (got $sum).');
  }
}

void validateModelInput(Float32List input, {required int expectedLength}) {
  if (input.length != expectedLength) {
    throw ArgumentError(
      'Input buffer length mismatch: expected $expectedLength, '
      'got ${input.length}',
    );
  }
  for (final value in input) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError('Input contains NaN or Infinity.');
    }
    // The model expects raw 0..255 pixel values; the app applies no
    // normalization, so anything outside this range is preprocessing gone
    // wrong and must fail loudly.
    if (value < 0 || value > 255) {
      throw ArgumentError(
        'Input pixel value out of 0..255 range: $value.',
      );
    }
  }
}

class WasteClassifierService implements WasteClassifier {
  static const defaultAssetPath =
      'lib/services/tflite/garbage_mobilenetv4_small.tflite';

  final String assetPath;
  final Uint8List? modelBytes;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<int> _inputShape = const [1, 224, 224, 3];
  bool _isInitialized = false;
  Future<void>? _initializing;
  bool _disposed = false;

  WasteClassifierService({
    this.assetPath = defaultAssetPath,
    this.modelBytes,
  });

  @override
  bool get isInitialized => _isInitialized;

  List<int> get inputShape => List.unmodifiable(_inputShape);

  int get inputWidth => _inputShape[2];

  int get inputHeight => _inputShape[1];

  @override
  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    // Shared future: concurrent callers wait for one load; clearing it on
    // failure keeps retries possible.
    return _initializing ??= _doInitialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _doInitialize() async {
    if (_disposed) {
      throw StateError('WasteClassifierService has been disposed.');
    }

    final Uint8List bytes;
    if (modelBytes != null) {
      bytes = modelBytes!;
    } else {
      final ByteData data = await rootBundle.load(assetPath);
      bytes = data.buffer.asUint8List();
    }

    final Interpreter interpreter;
    try {
      interpreter = Interpreter.fromBuffer(bytes);
      interpreter.allocateTensors();
    } catch (e) {
      throw StateError(
        'Failed to create LiteRT interpreter for $assetPath: $e',
      );
    }

    try {
      _validateContract(interpreter);
      _inputShape = interpreter.getInputTensor(0).shape;
      _isolateInterpreter = await IsolateInterpreter.create(
        address: interpreter.address,
        debugName: 'WasteClassifierIsolate',
      );
    } catch (e) {
      interpreter.close();
      rethrow;
    }

    _interpreter = interpreter;
    _isInitialized = true;
  }

  void _validateContract(Interpreter interpreter) {
    final inputTensors = interpreter.getInputTensors();
    if (inputTensors.length != 1) {
      throw StateError(
        'Model must have exactly one input tensor, found ${inputTensors.length}.',
      );
    }
    final input = inputTensors.single;
    const expectedInput = [1, 224, 224, 3];
    final shapeOk = input.shape.length == 4 &&
        input.shape[0] == expectedInput[0] &&
        input.shape[1] == expectedInput[1] &&
        input.shape[2] == expectedInput[2] &&
        input.shape[3] == expectedInput[3];
    if (input.type != TensorType.float32 || !shapeOk) {
      throw StateError(
        'Model input tensor incompatible: ${input.shape} / ${input.type}. '
        'Expected float32 [1, 224, 224, 3].',
      );
    }

    final outputTensors = interpreter.getOutputTensors();
    if (outputTensors.length != 1) {
      throw StateError(
        'Model must have exactly one output tensor, found ${outputTensors.length}.',
      );
    }
    final output = outputTensors.single;
    if (output.type != TensorType.float32 ||
        output.shape.length != 2 ||
        output.shape[0] != 1 ||
        output.shape[1] != kWasteClasses.length) {
      throw StateError(
        'Model output tensor incompatible: ${output.shape} / ${output.type}. '
        'Expected float32 [1, ${kWasteClasses.length}].',
      );
    }
  }

  @override
  Future<ClassificationResult> classify(Float32List rgbInput) async {
    final isolateInterpreter = _isolateInterpreter;
    if (isolateInterpreter == null || !_isInitialized) {
      throw StateError('WasteClassifierService is not initialized');
    }

    validateModelInput(
      rgbInput,
      expectedLength: 224 * 224 * 3,
    );

    final output = Float32List(kWasteClasses.length);
    await isolateInterpreter.run(
      rgbInput.buffer.asUint8List(),
      output,
    );

    validateProbabilities(output);
    final index = pickTopIndex(output);
    return ClassificationResult.fromIndex(index, output[index]);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isInitialized = false;
    _isolateInterpreter?.close();
    _interpreter?.close();
  }
}
