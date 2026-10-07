import 'dart:ui';

import 'waste_category.dart';

class const WasteClassInfo({
  required final String id,
  required final String displayName,
  required final WasteCategory category,
}) {}

const List<WasteClassInfo> kSupportedWasteClasses = [
  WasteClassInfo(
    id: 'apple',
    displayName: 'Apel',
    category: WasteCategory.organik,
  ),
  WasteClassInfo(
    id: 'banana',
    displayName: 'Pisang',
    category: WasteCategory.organik,
  ),
  WasteClassInfo(
    id: 'milk_carton',
    displayName: 'Karton Susu',
    category: WasteCategory.kertas,
  ),
  WasteClassInfo(
    id: 'paper_container',
    displayName: 'Wadah Kertas',
    category: WasteCategory.kertas,
  ),
  WasteClassInfo(
    id: 'paper_roll',
    displayName: 'Gulungan Kertas',
    category: WasteCategory.kertas,
  ),
  WasteClassInfo(
    id: 'plastic_bag',
    displayName: 'Kantong Plastik',
    category: WasteCategory.plastik,
  ),
  WasteClassInfo(
    id: 'plastic_bottle',
    displayName: 'Botol Plastik',
    category: WasteCategory.plastik,
  ),
  WasteClassInfo(
    id: 'plastic_container',
    displayName: 'Wadah Plastik',
    category: WasteCategory.plastik,
  ),
];

class DetectionResult {
  final Rect normalizedRect;
  final int classIndex;
  final String label;
  final String displayName;
  final WasteCategory category;
  final double score;

  const DetectionResult({
    required this.normalizedRect,
    required this.classIndex,
    required this.label,
    required this.displayName,
    required this.category,
    required this.score,
  });

  @override
  String toString() =>
      'DetectionResult($displayName, ${(score * 100).toStringAsFixed(1)}%, ${category.label}, $normalizedRect)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionResult &&
          runtimeType == other.runtimeType &&
          classIndex == other.classIndex &&
          normalizedRect == other.normalizedRect &&
          score == other.score;

  @override
  int get hashCode => Object.hash(classIndex, normalizedRect, score);
}
