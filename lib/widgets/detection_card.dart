import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../models/waste_category.dart';
import '../theme/app_theme.dart';

class DetectionCard extends StatelessWidget {
  final DetectionResult detection;

  const DetectionCard({
    super.key,
    required this.detection,
  });

  @override
  Widget build(BuildContext context) {
    final Color categoryColor = AppColors.getCategoryColor(detection.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              _getCategoryIcon(detection.category),
              color: categoryColor,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detection.displayName,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2.0),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        detection.category.label,
                        style: const TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Keyakinan: ${(detection.score * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(WasteCategory category) {
    switch (category) {
      case WasteCategory.organik:
        return Icons.eco_outlined;
      case WasteCategory.kertas:
        return Icons.article_outlined;
      case WasteCategory.plastik:
        return Icons.recycling_outlined;
    }
  }
}
