import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';
import '../services/image_processor.dart';
import '../services/tflite/waste_detector_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detection_card.dart';
import '../widgets/detection_overlay.dart';

class GalleryResultScreen extends StatefulWidget {
  final Uint8List initialImageBytes;
  final List<DetectionResult> initialDetections;
  final WasteDetector detector;

  const GalleryResultScreen({
    super.key,
    required this.initialImageBytes,
    required this.initialDetections,
    required this.detector,
  });

  @override
  State<GalleryResultScreen> createState() => _GalleryResultScreenState();
}

class _GalleryResultScreenState extends State<GalleryResultScreen> {
  late Uint8List _imageBytes;
  late List<DetectionResult> _detections;
  bool _isProcessing = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.initialImageBytes;
    _detections = widget.initialDetections;
  }

  Future<void> _pickAnotherImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (file == null) return;

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      final bytes = await file.readAsBytes();
      final inputBuffer = ImageProcessor.processGalleryImage(bytes);
      final results = await widget.detector.detect(inputBuffer);

      setState(() {
        _imageBytes = bytes;
        _detections = results;
        _isProcessing = false;
      });
    } catch (e) {
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
        title: const Text('Hasil Analisis Foto'),
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

                    // Image with detection overlay
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        color: AppColors.surfaceWarm,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.memory(
                                  _imageBytes,
                                  width: constraints.maxWidth,
                                  fit: BoxFit.contain,
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: DetectionOverlayPainter(
                                      detections: _detections,
                                      previewSize: Size(constraints.maxWidth, constraints.maxWidth),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Detection header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Objek Terdeteksi',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: _detections.isNotEmpty
                                ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                                : AppColors.surfaceWarm,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            '${_detections.length} objek',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: _detections.isNotEmpty
                                  ? AppColors.primaryGreenDark
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),

                    // Results list or empty state
                    if (_detections.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.search_off_outlined,
                              size: 40.0,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(height: 10.0),
                            Text(
                              'Belum ada objek yang dikenali',
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              'Foto belum memuat salah satu dari 8 jenis sampah yang didukung model EcoSort.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.0,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      for (final detection in _detections)
                        DetectionCard(detection: detection),
                    ],

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
