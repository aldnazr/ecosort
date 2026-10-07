import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/tflite/waste_detector_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final detector = WasteDetectorService();
  runApp(EcoSortApp(detector: detector));
}

class EcoSortApp extends StatelessWidget {
  final WasteDetector detector;

  const EcoSortApp({
    super.key,
    required this.detector,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoSort',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: HomeScreen(detector: detector),
    );
  }
}
