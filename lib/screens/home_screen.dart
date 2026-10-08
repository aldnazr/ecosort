import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/classification_result.dart';
import '../services/image_processor.dart';
import '../services/tflite/waste_classifier_service.dart';
import '../theme/app_theme.dart';
import 'camera_screen.dart';
import 'gallery_result_screen.dart';

class HomeScreen extends StatefulWidget {
  final WasteClassifier classifier;

  const HomeScreen({
    super.key,
    required this.classifier,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProcessingGallery = false;
  final ImagePicker _picker = ImagePicker();

  void _startCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraScreen(classifier: widget.classifier),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessingGallery) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (file == null || !mounted) return;

      setState(() {
        _isProcessingGallery = true;
      });

      await widget.classifier.initialize();

      final Uint8List bytes = await file.readAsBytes();
      final Float32List inputBuffer = await processGalleryImage(bytes);
      final ClassificationResult result = await widget.classifier.classify(inputBuffer);

      if (!mounted) return;

      setState(() {
        _isProcessingGallery = false;
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GalleryResultScreen(
            initialImageBytes: bytes,
            initialClassification: result,
            classifier: widget.classifier,
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

                    // Supported classes overview card
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
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [
                              for (final wasteClass in kWasteClasses)
                                _buildClassBadge(wasteClass.displayName),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          const Text(
                            'Isi foto dengan satu jenis sampah agar klasifikasi lebih akurat. Skor model bukan ukuran akurasi.',
                            style: TextStyle(
                              fontSize: 13.0,
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
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

  Widget _buildClassBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryGreenDark,
        ),
      ),
    );
  }
}