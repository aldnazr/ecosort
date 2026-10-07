import 'package:flutter/material.dart';
import '../models/waste_category.dart';

class AppColors {
  // Natural leaf green & warm cream palette
  static const Color primaryGreen = Color(0xFF285430);
  static const Color primaryGreenDark = Color(0xFF1E3F24);
  static const Color primaryGreenLight = Color(0xFF437A4C);

  static const Color backgroundCream = Color(0xFFF7F5EE);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceWarm = Color(0xFFEFECE2);

  static const Color textDark = Color(0xFF1C241D);
  static const Color textMuted = Color(0xFF5A665D);
  static const Color borderSubtle = Color(0xFFDCD7CA);

  // Category & detection accent colors (WCAG AA compliant contrast)
  static const Color categoryOrganik = Color(0xFF2E7D32);
  static const Color categoryKertas = Color(0xFF0D6EFD);
  static const Color categoryPlastik = Color(0xFFD97706);

  static const Color detectionBox = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFC53030);

  static Color getCategoryColor(WasteCategory category) {
    switch (category) {
      case WasteCategory.organik:
        return categoryOrganik;
      case WasteCategory.kertas:
        return categoryKertas;
      case WasteCategory.plastik:
        return categoryPlastik;
    }
  }
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreen,
        onPrimary: Colors.white,
        surface: AppColors.surfaceWhite,
        onSurface: AppColors.textDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundCream,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundCream,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
