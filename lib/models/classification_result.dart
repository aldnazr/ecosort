class WasteClassInfo {
  final String id;
  final String displayName;

  const WasteClassInfo({
    required this.id,
    required this.displayName,
  });
}

const List<WasteClassInfo> kWasteClasses = [
  WasteClassInfo(id: 'cardboard', displayName: 'Kardus'),
  WasteClassInfo(id: 'glass', displayName: 'Kaca'),
  WasteClassInfo(id: 'metal', displayName: 'Logam'),
  WasteClassInfo(id: 'paper', displayName: 'Kertas'),
  WasteClassInfo(id: 'plastic', displayName: 'Plastik'),
  WasteClassInfo(id: 'trash', displayName: 'Sampah lainnya'),
];

class ClassificationResult {
  final int classIndex;
  final String label;
  final String displayName;
  final double score;

  const ClassificationResult({
    required this.classIndex,
    required this.label,
    required this.displayName,
    required this.score,
  });

  factory ClassificationResult.fromIndex(int classIndex, double score) {
    if (classIndex < 0 || classIndex >= kWasteClasses.length) {
      throw RangeError.range(
        classIndex,
        0,
        kWasteClasses.length - 1,
        'classIndex',
        'Model output index is outside the supported waste classes.',
      );
    }
    final info = kWasteClasses[classIndex];
    return ClassificationResult(
      classIndex: classIndex,
      label: info.id,
      displayName: info.displayName,
      score: score,
    );
  }

  @override
  String toString() =>
      'ClassificationResult($displayName, ${(score * 100).toStringAsFixed(1)}%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassificationResult &&
          runtimeType == other.runtimeType &&
          classIndex == other.classIndex &&
          score == other.score;

  @override
  int get hashCode => Object.hash(classIndex, score);
}
