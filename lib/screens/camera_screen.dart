import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:image_picker/image_picker.dart';
import '../models/classification_result.dart';
import '../services/image_processor.dart';
import '../services/tflite/waste_classifier_service.dart';
import '../theme/app_theme.dart';
import '../widgets/classification_card.dart';
import 'gallery_result_screen.dart';

class CameraScreen extends StatefulWidget {
  final WasteClassifier classifier;
  final List<CameraDescription>? availableCameras;

  const CameraScreen({
    super.key,
    required this.classifier,
    this.availableCameras,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isSettingUp = false;
  bool _isInferencing = false;
  bool _isPicking = false;
  String? _errorMessage;
  bool _isPermissionDenied = false;
  DateTime _lastInferenceTime = DateTime.fromMillisecondsSinceEpoch(0);
  ClassificationResult? _classification;
  String? _resultError;
  Future<void>? _inFlight;
  Orientation _deviceOrientation = Orientation.portrait;  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stopStreaming();
      final cameraController = _controller;
      _controller = null;
      cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // The picker or the result screen may be in front; only restore the
      // camera when this route is visible and the app is truly resumed.
      if (_isPicking || !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      _restoreCamera();
    }
  }

  Future<void> _setupCamera() async {
    if (_isSettingUp) return;
    _isSettingUp = true;
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
        _isPermissionDenied = false;
      });

      try {
        await widget.classifier.initialize();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Model klasifikasi gagal dimuat: $e';
        });
        return;
      }

      // Release any previous controller before creating a new one.
      final oldController = _controller;
      _controller = null;
      await oldController?.dispose();

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
    } finally {
      _isSettingUp = false;
    }
  }

  void _restoreCamera() {
    if (_controller == null || !_controller!.value.isInitialized) {
      _setupCamera();
    } else {
      _startStreaming();
    }
  }

  void _startStreaming() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isStreamingImages) return;

    controller.startImageStream((CameraImage image) {
      final now = DateTime.now();
      // Backpressure throttle: minimum 350ms between frames and drop frames
      // while an inference is still running (no unbounded queue).
      if (_isInferencing ||
          now.difference(_lastInferenceTime).inMilliseconds < 350) {
        return;
      }

      _isInferencing = true;
      _lastInferenceTime = now;

      _inFlight = _runInferenceOnFrame(image);
    });
  }

  Future<void> _runInferenceOnFrame(CameraImage image) async {
    try {
      final controller = _controller;
      if (controller == null) return;

      final int rotation = computeFrameRotation(
        sensorOrientation: controller.description.sensorOrientation,
        deviceOrientation: _deviceOrientation == Orientation.portrait
            ? DeviceOrientation.portraitUp
            : DeviceOrientation.landscapeLeft,
        lensDirection: controller.description.lensDirection,
      );

      final Float32List rgbInput = await processCameraImage(
        image: image,
        rotation: rotation,
      );

      final ClassificationResult result = await widget.classifier.classify(rgbInput);

      if (mounted) {
        setState(() {
          _classification = result;
          _resultError = null;
        });
      }
    } catch (e) {
      // Frame failures can be transient, but a stale prediction must not
      // linger as if it belonged to the current frame.
      if (mounted) {
        setState(() {
          _classification = null;
          _resultError = 'Gagal memproses frame kamera: $e';
        });
      }
    } finally {
      _isInferencing = false;
      _inFlight = null;
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
    if (_isPicking) return;
    _isPicking = true;

    await _stopStreaming();
    // One shared interpreter: wait for the live frame inference to finish
    // before classifying the picked photo.
    await _inFlight;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final Float32List inputBuffer = await processGalleryImage(bytes);
      final ClassificationResult result = await widget.classifier.classify(inputBuffer);

      if (!mounted) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses gambar galeri: $e')),
        );
      }
    } finally {
      _isPicking = false;
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        _restoreCamera();
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
    _deviceOrientation = MediaQuery.orientationOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Klasifikasi Langsung',
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
                color: AppColors.warningAmber,
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

    return Column(
      children: [
        // Camera preview
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
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
                const Text(
                  'Hasil Klasifikasi',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4.0),
                const Text(
                  'Tips: isi frame dengan satu jenis sampah agar hasil lebih akurat.',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8.0),
                Expanded(
                  child: _resultError != null
                      ? Text(
                          _resultError!,
                          style: const TextStyle(
                            fontSize: 13.0,
                            color: AppColors.errorRed,
                          ),
                        )
                      : _classification == null
                          ? Center(
                              child: Text(
                                'Arahkan kamera ke satu jenis sampah untuk diklasifikasi.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: AppColors.textMuted.withValues(alpha: 0.8),
                                ),
                              ),
                            )
                          : ClassificationCard(result: _classification!),
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