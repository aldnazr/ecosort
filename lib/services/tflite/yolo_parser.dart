import 'dart:math' as math;
import 'dart:ui';
import '../../models/detection_result.dart';

class YoloParser {
  static const double defaultScoreThreshold = 0.30;
  static const double defaultIouThreshold = 0.40;

  static List<DetectionResult> parseOutput({
    required List<double> rawOutput,
    required List<int> shape,
    double scoreThreshold = defaultScoreThreshold,
    double iouThreshold = defaultIouThreshold,
  }) {
    if (shape.length != 3 || shape[0] != 1) {
      throw ArgumentError('Invalid output shape: $shape');
    }

    final int dim1 = shape[1];
    final int dim2 = shape[2];

    final bool isChannelsFirst = (dim1 == 12);
    final bool isChannelsLast = (dim2 == 12);

    if (!isChannelsFirst && !isChannelsLast) {
      throw ArgumentError(
          'Output tensor does not have 12 channels (4 box coords + 8 classes). Shape: $shape');
    }

    final int numAnchors = isChannelsFirst ? dim2 : dim1;
    final List<DetectionResult> candidates = [];

    for (int a = 0; a < numAnchors; a++) {
      double cx, cy, w, h;

      if (isChannelsFirst) {
        cx = rawOutput[0 * numAnchors + a];
        cy = rawOutput[1 * numAnchors + a];
        w = rawOutput[2 * numAnchors + a];
        h = rawOutput[3 * numAnchors + a];
      } else {
        final int base = a * 12;
        cx = rawOutput[base + 0];
        cy = rawOutput[base + 1];
        w = rawOutput[base + 2];
        h = rawOutput[base + 3];
      }

      if (cx.isNaN ||
          cy.isNaN ||
          w.isNaN ||
          h.isNaN ||
          cx.isInfinite ||
          cy.isInfinite ||
          w.isInfinite ||
          h.isInfinite) {
        continue;
      }

      if (w <= 0.0 || h <= 0.0) {
        continue;
      }

      // Find highest class score among the 8 classes
      double bestScore = 0.0;
      int bestClass = -1;

      for (int c = 0; c < 8; c++) {
        double score;
        if (isChannelsFirst) {
          score = rawOutput[(4 + c) * numAnchors + a];
        } else {
          score = rawOutput[a * 12 + 4 + c];
        }

        if (!score.isNaN && !score.isInfinite && score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestClass < 0 || bestScore <= scoreThreshold) {
        continue;
      }

      final double left = (cx - (w / 2.0)).clamp(0.0, 1.0);
      final double top = (cy - (h / 2.0)).clamp(0.0, 1.0);
      final double right = (cx + (w / 2.0)).clamp(0.0, 1.0);
      final double bottom = (cy + (h / 2.0)).clamp(0.0, 1.0);

      final double boxWidth = right - left;
      final double boxHeight = bottom - top;

      if (boxWidth <= 0.005 || boxHeight <= 0.005) {
        continue;
      }

      final classInfo = kSupportedWasteClasses[bestClass];

      candidates.add(
        DetectionResult(
          normalizedRect: Rect.fromLTWH(left, top, boxWidth, boxHeight),
          classIndex: bestClass,
          label: classInfo.id,
          displayName: classInfo.displayName,
          category: classInfo.category,
          score: bestScore,
        ),
      );
    }

    return applyNms(candidates, iouThreshold: iouThreshold);
  }

  static List<DetectionResult> applyNms(
    List<DetectionResult> candidates, {
    double iouThreshold = defaultIouThreshold,
  }) {
    if (candidates.isEmpty) return const [];

    // Sort descending by score
    final sorted = List<DetectionResult>.from(candidates)
      ..sort((a, b) => b.score.compareTo(a.score));

    final List<DetectionResult> selected = [];

    for (final current in sorted) {
      bool suppress = false;
      for (final prev in selected) {
        if (current.classIndex == prev.classIndex) {
          final iou = calculateIoU(current.normalizedRect, prev.normalizedRect);
          if (iou > iouThreshold) {
            suppress = true;
            break;
          }
        }
      }
      if (!suppress) {
        selected.add(current);
      }
    }

    return List.unmodifiable(selected);
  }

  static double calculateIoU(Rect a, Rect b) {
    final double left = math.max(a.left, b.left);
    final double top = math.max(a.top, b.top);
    final double right = math.min(a.right, b.right);
    final double bottom = math.min(a.bottom, b.bottom);

    final double width = math.max(0.0, right - left);
    final double height = math.max(0.0, bottom - top);
    final double intersection = width * height;

    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;
    final double union = areaA + areaB - intersection;

    if (union <= 0.0) return 0.0;
    return intersection / union;
  }
}
