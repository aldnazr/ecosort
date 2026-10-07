import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import '../../models/detection_result.dart';
import 'yolo_parser.dart';

abstract class WasteDetector {
  bool get isInitialized;
  List<int> get inputShape;
  int get inputWidth;
  int get inputHeight;
  Future<void> initialize();
  Future<List<DetectionResult>> detect(Float32List rgbNormalizedInput);
  void dispose();
}

class WasteDetectorService implements WasteDetector {
  static const String defaultAssetPath = 'lib/services/tflite/best_int8.tflite';
  final String assetPath;
  final Uint8List? modelBytes;

  Interpreter? _interpreter;
  List<int> _inputShape = [1, 320, 320, 3];
  List<int> _outputShape = [1, 12, 2100];
  int _outputLength = 12 * 2100;
  bool _isInitialized = false;

  WasteDetectorService({
    this.assetPath = defaultAssetPath,
    this.modelBytes,
  });

  @override
  bool get isInitialized => _isInitialized;

  @override
  List<int> get inputShape => List.unmodifiable(_inputShape);

  @override
  int get inputWidth => _inputShape[2];

  @override
  int get inputHeight => _inputShape[1];

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final Uint8List bytes;
    if (modelBytes != null) {
      bytes = modelBytes!;
    } else {
      final ByteData data = await rootBundle.load(assetPath);
      bytes = data.buffer.asUint8List();
    }

    final interpreter = Interpreter.fromBuffer(bytes);
    interpreter.allocateTensors();

    final inputTensors = interpreter.getInputTensors();
    if (inputTensors.isEmpty) {
      interpreter.close();
      throw StateError('Model has no input tensors');
    }

    final inputTensor = inputTensors.first;
    _inputShape = inputTensor.shape;

    if (_inputShape.length != 4 ||
        _inputShape[0] != 1 ||
        _inputShape[3] != 3) {
      interpreter.close();
      throw StateError('Unexpected input tensor shape: $_inputShape. Expected [1, H, W, 3]');
    }

    final outputTensors = interpreter.getOutputTensors();
    if (outputTensors.isEmpty) {
      interpreter.close();
      throw StateError('Model has no output tensors');
    }

    final outputTensor = outputTensors.first;
    _outputShape = outputTensor.shape;

    int totalElements = 1;
    for (final s in _outputShape) {
      totalElements *= s;
    }
    _outputLength = totalElements;

    _interpreter = interpreter;
    _isInitialized = true;
  }

  @override
  Future<List<DetectionResult>> detect(Float32List rgbNormalizedInput) async {
    final interpreter = _interpreter;
    if (interpreter == null || !_isInitialized) {
      throw StateError('WasteDetectorService is not initialized');
    }

    final int expectedInputLength = _inputShape[0] * _inputShape[1] * _inputShape[2] * _inputShape[3];
    if (rgbNormalizedInput.length != expectedInputLength) {
      throw ArgumentError(
          'Input buffer length mismatch: expected $expectedInputLength, got ${rgbNormalizedInput.length}');
    }

    final outputBuffer = Float32List(_outputLength);
    final inputs = [rgbNormalizedInput.buffer.asUint8List()];
    final outputs = {0: outputBuffer.buffer.asUint8List()};

    interpreter.runForMultipleInputs(inputs, outputs);

    final List<double> rawOutput = outputBuffer.toList(growable: false);
    return YoloParser.parseOutput(
      rawOutput: rawOutput,
      shape: _outputShape,
    );
  }

  @override
  void dispose() {
    _isInitialized = false;
    _interpreter?.close();
    _interpreter = null;
  }
}
