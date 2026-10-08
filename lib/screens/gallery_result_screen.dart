import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/classification_result.dart';
import '../services/image_processor.dart';
import '../services/tflite/waste_classifier_service.dart';
import '../theme/app_theme.dart';
import '../widgets/classification_card.dart';

class GalleryResultScreen extends StatefulWidget {
  final Uint8List initialImageBytes;
  final ClassificationResult initialClassification;
  final WasteClassifier classifier;

  const GalleryResultScreen({
    super.key,
    required this.initialImageBytes,
    required this.initialClassification,
    required this.classifier,
  });

  @override
  State<GalleryResultScreen> createState() => _GalleryResultScreenState();
}

class _GalleryResultScreenState extends State<GalleryResultScreen> {
  late Uint8List _imageBytes;
  late ClassificationResult _classification;
  bool _isProcessing = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.initialImageBytes;
    _classification = widget.initialClassification;
  }

  Future<void> _pickAnotherImage() async {
    if (_isProcessing) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      // Cancellation keeps the previous photo and its result.
      if (file == null || !mounted) return;

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      final bytes = await file.readAsBytes();
      final inputBuffer = await processGalleryImage(bytes);
      final result = await widget.classifier.classify(inputBuffer);

      if (!mounted) return;

      // Attach the new result together with the photo it came from only
      // after inference succeeded; a failure keeps the previous pair.
      setState(() {
        _imageBytes = bytes;
        _classification = result;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memproses gambar: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Klasifikasi Foto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Kembali',
        ),
      ),
      body: SafeArea(
        child: _isProcessing
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: AppColors.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: AppColors.errorRed),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.errorRed),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // Photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        color: AppColors.surfaceWarm,
                        child: Image.memory(
                          _imageBytes,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    const Text(
                      'Hasil Klasifikasi',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    const Text(
                      'Skor model bukan ukuran akurasi dan model tidak menjamin pengenalan benda di luar enam kelas.',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    ClassificationCard(result: _classification),

                    const SizedBox(height: 24.0),

                    // Action buttons
                    ElevatedButton.icon(
                      onPressed: _pickAnotherImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Pilih Foto Lain'),
                    ),
                    const SizedBox(height: 10.0),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kembali'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}