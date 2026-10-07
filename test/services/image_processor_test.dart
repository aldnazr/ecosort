import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/services/image_processor.dart';
import 'package:image/image.dart' as img;

void main() {
  group('ImageProcessor', () {
    test('processGalleryImage decodes, resizes, and normalizes properly', () {
      final testImage = img.Image(width: 640, height: 480);
      for (var y = 0; y < 480; y++) {
        for (var x = 0; x < 640; x++) {
          testImage.setPixelRgb(x, y, 255, 128, 0);
        }
      }
      final pngBytes = Uint8List.fromList(img.encodePng(testImage));

      final buffer = ImageProcessor.processGalleryImage(pngBytes);
      expect(buffer.length, 320 * 320 * 3);

      // Check normalized color values
      expect(buffer[0], closeTo(1.0, 0.05)); // R ~ 1.0
      expect(buffer[1], closeTo(128 / 255.0, 0.05)); // G ~ 0.5
      expect(buffer[2], closeTo(0.0, 0.05)); // B ~ 0.0
    });

    test('processCameraImage handles simulated YUV420 frame', () {
      const int width = 640;
      const int height = 480;

      final yBytes = Uint8List(width * height)..fillRange(0, width * height, 200);
      final uBytes = Uint8List((width ~/ 2) * (height ~/ 2))..fillRange(0, (width ~/ 2) * (height ~/ 2), 128);
      final vBytes = Uint8List((width ~/ 2) * (height ~/ 2))..fillRange(0, (width ~/ 2) * (height ~/ 2), 128);

      final planes = [
        CameraImagePlane(bytes: yBytes, bytesPerRow: width, bytesPerPixel: 1, width: width, height: height),
        CameraImagePlane(bytes: uBytes, bytesPerRow: width ~/ 2, bytesPerPixel: 1, width: width ~/ 2, height: height ~/ 2),
        CameraImagePlane(bytes: vBytes, bytesPerRow: width ~/ 2, bytesPerPixel: 1, width: width ~/ 2, height: height ~/ 2),
      ];

      final cameraImage = CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
          planes: planes,
          width: width,
          height: height,
        ),
      );

      final buffer90 = ImageProcessor.processCameraImage(cameraImage, rotation: 90);
      expect(buffer90.length, 320 * 320 * 3);
      expect(buffer90[0], inInclusiveRange(0.0, 1.0));

      final buffer0 = ImageProcessor.processCameraImage(cameraImage, rotation: 0);
      expect(buffer0.length, 320 * 320 * 3);
    });

    test('processCameraImage handles simulated BGRA8888 frame', () {
      const int width = 320;
      const int height = 240;

      final bgraBytes = Uint8List(width * height * 4);
      for (int i = 0; i < bgraBytes.length; i += 4) {
        bgraBytes[i] = 50; // B
        bgraBytes[i + 1] = 150; // G
        bgraBytes[i + 2] = 250; // R
        bgraBytes[i + 3] = 255; // A
      }

      final planes = [
        CameraImagePlane(bytes: bgraBytes, bytesPerRow: width * 4, bytesPerPixel: 4, width: width, height: height),
      ];

      final cameraImage = CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 1),
          planes: planes,
          width: width,
          height: height,
        ),
      );

      final buffer = ImageProcessor.processCameraImage(cameraImage, rotation: 0);
      expect(buffer.length, 320 * 320 * 3);
      expect(buffer[0], closeTo(250 / 255.0, 0.01)); // R
      expect(buffer[1], closeTo(150 / 255.0, 0.01)); // G
      expect(buffer[2], closeTo(50 / 255.0, 0.01)); // B
    });
  });
}
