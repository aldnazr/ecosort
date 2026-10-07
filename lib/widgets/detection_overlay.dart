import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../theme/app_theme.dart';

class DetectionOverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size previewSize;
  final BoxFit fit;

  DetectionOverlayPainter({
    required this.detections,
    required this.previewSize,
    this.fit = BoxFit.contain,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || previewSize.isEmpty || size.isEmpty) return;

    final double scaleX;
    final double scaleY;
    final double offsetX;
    final double offsetY;

    if (fit == BoxFit.cover) {
      final double scale = (size.width / previewSize.width) > (size.height / previewSize.height)
          ? (size.width / previewSize.width)
          : (size.height / previewSize.height);
      scaleX = scale;
      scaleY = scale;
      offsetX = (size.width - previewSize.width * scale) / 2.0;
      offsetY = (size.height - previewSize.height * scale) / 2.0;
    } else {
      // BoxFit.contain or default direct mapping
      scaleX = size.width;
      scaleY = size.height;
      offsetX = 0.0;
      offsetY = 0.0;
    }

    for (final detection in detections) {
      final categoryColor = AppColors.getCategoryColor(detection.category);

      final double left;
      final double top;
      final double width;
      final double height;

      if (fit == BoxFit.cover) {
        left = offsetX + detection.normalizedRect.left * previewSize.width * scaleX;
        top = offsetY + detection.normalizedRect.top * previewSize.height * scaleY;
        width = detection.normalizedRect.width * previewSize.width * scaleX;
        height = detection.normalizedRect.height * previewSize.height * scaleY;
      } else {
        left = detection.normalizedRect.left * scaleX;
        top = detection.normalizedRect.top * scaleY;
        width = detection.normalizedRect.width * scaleX;
        height = detection.normalizedRect.height * scaleY;
      }

      final Rect rect = Rect.fromLTWH(left, top, width, height);

      // Bounding box border
      final boxPaint = Paint()
        ..color = categoryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      // Semi-transparent background fill
      final fillPaint = Paint()
        ..color = categoryColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        boxPaint,
      );

      // Corner accent markers
      final cornerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      const double cornerLen = 12.0;
      // Top-left
      canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLen, rect.top), cornerPaint);
      canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLen), cornerPaint);
      // Top-right
      canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cornerLen, rect.top), cornerPaint);
      canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLen), cornerPaint);
      // Bottom-left
      canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLen, rect.bottom), cornerPaint);
      canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLen), cornerPaint);
      // Bottom-right
      canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - cornerLen, rect.bottom), cornerPaint);
      canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLen), cornerPaint);

      // Label badge
      final String labelText =
          '${detection.displayName} ${(detection.score * 100).toInt()}% • ${detection.category.label}';

      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final double badgeWidth = textPainter.width + 12.0;
      final double badgeHeight = textPainter.height + 6.0;

      double badgeLeft = rect.left;
      double badgeTop = rect.top - badgeHeight - 2.0;
      if (badgeTop < 0) {
        badgeTop = rect.top + 2.0;
      }
      if (badgeLeft + badgeWidth > size.width) {
        badgeLeft = size.width - badgeWidth - 4.0;
      }
      if (badgeLeft < 0) badgeLeft = 4.0;

      final badgeRect = Rect.fromLTWH(badgeLeft, badgeTop, badgeWidth, badgeHeight);
      final badgePaint = Paint()
        ..color = categoryColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
        badgePaint,
      );

      textPainter.paint(
        canvas,
        Offset(badgeLeft + 6.0, badgeTop + 3.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.previewSize != previewSize ||
        oldDelegate.fit != fit;
  }
}
