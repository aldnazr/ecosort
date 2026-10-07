import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';
import '../services/image_processor.dart';
import '../services/tflite/waste_detector_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detection_card.dart';
import '../widgets/detection_overlay.dart';
import 'gallery_result_screen.dart';

class CameraScreen extends StatefulWidget {
  final WasteDetector detector;
  final List<CameraDescription>? availableCameras;

  const CameraScreen({
    super.key,
    required this.detector,
    this.availableCameras,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isInferencing = false;
  String? _errorMessage;
  bool _isPermissionDenied = false;
  DateTime _lastInferenceTime = DateTime.now();
  List<DetectionResult> _detections = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopStreaming();
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  Future<void> _setupCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _isPermissionDenied = false;
    });

    try {
      if (!widget.detector.isInitialized) {
        await widget.detector.initialize();
      }

      _cameras = widget.availableCameras ?? await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Tidak ada sensor kamera yang ditemukan pada perangkat.';
          _isInitializing = false;
        });
        return;
      }

      // Prefer back camera
      final camera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _isInitializing = false;
      setState(() {});

      _startStreaming();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        if (e.code == 'CameraAccessDenied' ||
            e.code == 'CameraAccessDeniedWithoutPrompt' ||
            e.code == 'CameraAccessRestricted') {
          _isPermissionDenied = true;
          _errorMessage = 'Izin kamera ditolak. Silakan izinkan akses kamera di pengaturan perangkat.';
        } else {
          _errorMessage = 'Gagal membuka kamera: ${e.description ?? e.code}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Terjadi kesalahan saat menyiapkan kamera: $e';
      });
    }
  }

  void _startStreaming() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isStreamingImages) return;

    controller.startImageStream((CameraImage image) {
      final now = DateTime.now();
      // Backpressure throttle: minimum 350ms between frames and ignore if inference is ongoing
      if (_isInferencing || now.difference(_lastInferenceTime).inMilliseconds < 350) {
        return;
      }

      _isInferencing = true;
      _lastInferenceTime = now;

      final int rotation = controller.description.sensorOrientation;

      _runInferenceOnFrame(image, rotation);
    });
  }

  Future<void> _runInferenceOnFrame(CameraImage image, int rotation) async {
    try {
      final Float32List rgbInput = ImageProcessor.processCameraImage(
        image,
        rotation: rotation,
      );

      final List<DetectionResult> results = await widget.detector.detect(rgbInput);

      if (mounted) {
        setState(() {
          _detections = results;
        });
      }
    } catch (_) {
      // Ignore transient frame inference error to maintain stream stability
    } finally {
      _isInferencing = false;
    }
  }

  Future<void> _stopStreaming() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
  }

  Future<void> _openGallery() async {
    await _stopStreaming();

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (file == null) {
        _startStreaming();
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final Float32List inputBuffer = ImageProcessor.processGalleryImage(bytes);
      final List<DetectionResult> results = await widget.detector.detect(inputBuffer);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GalleryResultScreen(
            initialImageBytes: bytes,
            initialDetections: results,
            detector: widget.detector,
          ),
        ),
      );

      if (mounted) {
        _startStreaming();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses gambar galeri: $e')),
        );
        _startStreaming();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStreaming();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Deteksi Langsung',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Kembali',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Pilih dari Galeri',
            onPressed: _openGallery,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreenLight),
            SizedBox(height: 16),
            Text(
              'Menyiapkan kamera...',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPermissionDenied ? Icons.no_photography_outlined : Icons.error_outline,
                size: 48,
                color: AppColors.detectionBox,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _setupCamera,
                child: const Text('Coba Lagi'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                onPressed: _openGallery,
                child: const Text('Pilih dari Galeri'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final Size previewSize = controller.value.previewSize != null
        ? Size(controller.value.previewSize!.height, controller.value.previewSize!.width)
        : const Size(720, 1280);

    return Column(
      children: [
        // Camera preview with overlay
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                Positioned.fill(
                  child: CustomPaint(
                    painter: DetectionOverlayPainter(
                      detections: _detections,
                      previewSize: previewSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Scanning indicator pill
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Memindai',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Results bottom panel
        Expanded(
          flex: 2,
          child: Container(
            color: AppColors.backgroundCream,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hasil Deteksi',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      _detections.isEmpty ? '0 objek' : '${_detections.length} objek',
                      style: const TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Expanded(
                  child: _detections.isEmpty
                      ? Center(
                          child: Text(
                            'Arahkan kamera ke sampah untuk mendeteksi secara langsung.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: AppColors.textMuted.withValues(alpha: 0.8),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _detections.length,
                          itemBuilder: (context, index) {
                            return DetectionCard(detection: _detections[index]);
                          },
                        ),
                ),
                const SizedBox(height: 8.0),
                OutlinedButton.icon(
                  onPressed: _openGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pilih dari Galeri'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
