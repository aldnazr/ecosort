import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/tflite/waste_classifier_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EcoSortApp(classifier: WasteClassifierService()));
}

class EcoSortApp extends StatefulWidget {
  final WasteClassifier classifier;

  const EcoSortApp({
    super.key,
    required this.classifier,
  });

  @override
  State<EcoSortApp> createState() => _EcoSortAppState();
}

class _EcoSortAppState extends State<EcoSortApp> {
  @override
  void dispose() {
    widget.classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoSort',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: HomeScreen(classifier: widget.classifier),
    );
  }
}