import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';
import '../models/waste_category.dart';
import '../services/image_processor.dart';
import '../services/tflite/waste_detector_service.dart';
import '../theme/app_theme.dart';
import 'camera_screen.dart';
import 'gallery_result_screen.dart';

class HomeScreen extends StatefulWidget {
  final WasteDetector detector;

  const HomeScreen({
    super.key,
    required this.detector,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProcessingGallery = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _startCamera() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraScreen(detector: widget.detector),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (file == null) return;

      setState(() {
        _isProcessingGallery = true;
      });

      if (!widget.detector.isInitialized) {
        await widget.detector.initialize();
      }

      final Uint8List bytes = await file.readAsBytes();
      final Float32List inputBuffer = ImageProcessor.processGalleryImage(bytes);
      final List<DetectionResult> results = await widget.detector.detect(inputBuffer);

      if (!mounted) return;

      setState(() {
        _isProcessingGallery = false;
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GalleryResultScreen(
            initialImageBytes: bytes,
            initialDetections: results,
            detector: widget.detector,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingGallery = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menganalisis foto: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isProcessingGallery
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryGreen),
                    SizedBox(height: 16),
                    Text(
                      'Memproses foto...',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12.0),
                    // Header Brand
                    const Text(
                      'EcoSort',
                      style: TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreenDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    const Text(
                      'Klasifikasi sampah secara langsung dan luring menggunakan kecerdasan buatan.',
                      style: TextStyle(
                        fontSize: 15.0,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32.0),

                    // Supported categories overview card
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kategori Sampah Didukung',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 14.0),
                          _buildCategoryRow(
                            category: WasteCategory.organik,
                            items: 'Apel, Pisang',
                          ),
                          const Divider(height: 20.0, color: AppColors.surfaceWarm),
                          _buildCategoryRow(
                            category: WasteCategory.kertas,
                            items: 'Karton Susu, Wadah Kertas, Gulungan Kertas',
                          ),
                          const Divider(height: 20.0, color: AppColors.surfaceWarm),
                          _buildCategoryRow(
                            category: WasteCategory.plastik,
                            items: 'Kantong Plastik, Botol Plastik, Wadah Plastik',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36.0),

                    // Primary Action Buttons
                    ElevatedButton.icon(
                      onPressed: _startCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Mulai Kamera'),
                    ),
                    const SizedBox(height: 14.0),
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Pilih dari Galeri'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCategoryRow({
    required WasteCategory category,
    required String items,
  }) {
    final Color color = AppColors.getCategoryColor(category);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Text(
            category.label,
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            items,
            style: const TextStyle(
              fontSize: 13.0,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
