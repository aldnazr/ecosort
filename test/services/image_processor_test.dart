import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:ecosort/services/image_processor.dart';
import 'package:image/image.dart' as img;

CameraImage _cameraImage({
  required ImageFormatGroup group,
  required int width,
  required int height,
  required List<({Uint8List bytes, int bytesPerRow, int? bytesPerPixel})> planes,
}) {
  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: CameraImageFormat(group, raw: 0),
      width: width,
      height: height,
      lensAperture: null,
      sensorExposureTime: null,
      sensorSensitivity: null,
      planes: [
        for (final p in planes)
          CameraImagePlane(
            bytes: p.bytes,
            bytesPerRow: p.bytesPerRow,
            bytesPerPixel: p.bytesPerPixel,
          ),
      ],
    ),
  );
}

Uint8List _solidRgb(int width, int height, int r, int g, int b) {
  final data = Uint8List(width * height * 3);
  for (var i = 0; i < width * height; i++) {
    data[i * 3] = r;
    data[i * 3 + 1] = g;
    data[i * 3 + 2] = b;
  }
  return data;
}

void main() {
  group('rgbToModelInput', () {
    test('solid RGB proves 0..255 values, not 0..1, and exact NHWC length', () {
      final input = rgbToModelInput(_solidRgb(50, 50, 255, 128, 0), 50, 50);
      expect(input.length, 224 * 224 * 3);
      // R channel stays 255.0, G stays 128.0; a 0..1 preprocessing would
      // produce 1.0 / 0.5.
      for (var p = 0; p < 224 * 224; p++) {
        expect(input[p * 3], 255.0);
        expect(input[p * 3 + 1], 128.0);
        expect(input[p * 3 + 2], 0.0);
      }
    });

    test('non-square images are stretched without crop or letterbox', () {
      // 64x64: left half red, right half blue.
      final width = 64, height = 64;
      final rgb = Uint8List(width * height * 3);
      for (var row = 0; row < height; row++) {
        for (var col = 0; col < width; col++) {
          final blue = col >= width ~/ 2;
          final i = (row * width + col) * 3;
          rgb[i] = blue ? 0 : 255;
          rgb[i + 1] = 0;
          rgb[i + 2] = blue ? 255 : 0;
        }
      }
      final input = rgbToModelInput(rgb, width, height);

      // Column 0 samples the red edge, column 223 the blue edge: the whole
      // width is used. No crop and no padding rows: middle rows share the
      // same color as edge rows.
      for (var y = 0; y < 224; y++) {
        final left = (y * 224) * 3;
        final right = (y * 224 + 223) * 3;
        expect(input[left], 255.0, reason: 'row $y left edge');
        expect(input[left + 2], 0.0);
        expect(input[right], 0.0, reason: 'row $y right edge');
        expect(input[right + 2], 255.0);
      }
      expect(input[0], 255.0);
      expect(input[(223 * 224) * 3], 255.0);
    });

    test('rejects mismatched buffer length', () {
      expect(
        () => rgbToModelInput(Uint8List(10), 4, 4),
        throwsArgumentError,
      );
    });
  });

  group('rotateRgb', () {
    test('90 degrees clockwise swaps and reorders pixels', () {
      // 2x1: [red, blue]. Rotated CW 90 -> 1x2: top red, bottom blue.
      final rgb = Uint8List.fromList([255, 0, 0, 0, 0, 255]);
      final rotated = rotateRgb(rgb, 2, 1, 90);
      expect(rotated.width, 1);
      expect(rotated.height, 2);
      expect(rotated.rgb, [255, 0, 0, 0, 0, 255]);
    });

    test('270 degrees clockwise rotates the other way', () {
      final rgb = Uint8List.fromList([255, 0, 0, 0, 0, 255]);
      final rotated = rotateRgb(rgb, 2, 1, 270);
      expect(rotated.width, 1);
      expect(rotated.height, 2);
      expect(rotated.rgb, [0, 0, 255, 255, 0, 0]);
    });

    test('0 degrees returns the buffer unchanged', () {
      final rgb = Uint8List.fromList([1, 2, 3]);
      final rotated = rotateRgb(rgb, 1, 1, 0);
      expect(identical(rotated.rgb, rgb), isTrue);
    });

    test('180 degrees flips both axes', () {
      final rgb = Uint8List.fromList([255, 0, 0, 0, 0, 255]);
      final rotated = rotateRgb(rgb, 2, 1, 180);
      expect(rotated.rgb, [0, 0, 255, 255, 0, 0]);
    });

    test('rejects non-right-angle rotation', () {
      expect(() => rotateRgb(Uint8List(3), 1, 1, 45), throwsArgumentError);
    });
  });

  group('computeFrameRotation', () {
    test('back camera, portrait, sensor 90 -> 90', () {
      expect(
        computeFrameRotation(
          sensorOrientation: 90,
          deviceOrientation: DeviceOrientation.portraitUp,
          lensDirection: CameraLensDirection.back,
        ),
        90,
      );
    });

    test('back camera, landscapeRight, sensor 90 -> 180', () {
      expect(
        computeFrameRotation(
          sensorOrientation: 90,
          deviceOrientation: DeviceOrientation.landscapeRight,
          lensDirection: CameraLensDirection.back,
        ),
        180,
      );
    });

    test('back camera, portraitDown, sensor 90 -> 270', () {
      expect(
        computeFrameRotation(
          sensorOrientation: 90,
          deviceOrientation: DeviceOrientation.portraitDown,
          lensDirection: CameraLensDirection.back,
        ),
        270,
      );
    });

    test('front camera, portrait, sensor 270 -> 270', () {
      expect(
        computeFrameRotation(
          sensorOrientation: 270,
          deviceOrientation: DeviceOrientation.portraitUp,
          lensDirection: CameraLensDirection.front,
        ),
        270,
      );
    });

    test('front camera, landscapeRight, sensor 270 -> 180', () {
      expect(
        computeFrameRotation(
          sensorOrientation: 270,
          deviceOrientation: DeviceOrientation.landscapeRight,
          lensDirection: CameraLensDirection.front,
        ),
        180,
      );
    });
  });

  group('cameraFrameToRgb', () {
    test('yuv420 semi-planar with row and pixel strides', () {
      // 4x2 frame, gray Y=128, U=128, V=128 -> RGB 128,128,128.
      const width = 4, height = 2;
      final y = Uint8List.fromList([128, 128, 128, 128, 0, 0, 128, 128, 128, 128, 0, 0]);
      // One chroma row (height 2): two samples + one stride padding byte.
      final u = Uint8List.fromList([128, 128, 0]);
      final v = Uint8List.fromList([128, 128, 0]);
      final image = _cameraImage(
        group: ImageFormatGroup.yuv420,
        width: width,
        height: height,
        planes: [
          (bytes: y, bytesPerRow: 6, bytesPerPixel: 1),
          (bytes: u, bytesPerRow: 3, bytesPerPixel: 1),
          (bytes: v, bytesPerRow: 3, bytesPerPixel: 1),
        ],
      );

      final rgb = cameraFrameToRgb(image);
      expect(rgb.width, width);
      expect(rgb.height, height);
      expect(rgb.rgb, hasLength(width * height * 3));
      for (var i = 0; i < width * height; i++) {
        expect(rgb.rgb[i * 3], 128);
        expect(rgb.rgb[i * 3 + 1], 128);
        expect(rgb.rgb[i * 3 + 2], 128);
      }
    });

    test('yuv420 semi-planar with interleaved chroma (pixel stride 2)', () {
      // 2x2 red-ish frame: Y=76, U=84, V=255 -> R~254, G~0, B~0.
      const width = 2, height = 2;
      final y = Uint8List.fromList([76, 76, 76, 76]);
      // Interleaved UV: [U,V,U,V,pad]
      final u = Uint8List.fromList([84, 255, 84, 0]);
      final v = Uint8List.fromList([255, 84, 255, 0]);
      final image = _cameraImage(
        group: ImageFormatGroup.yuv420,
        width: width,
        height: height,
        planes: [
          (bytes: y, bytesPerRow: 2, bytesPerPixel: 1),
          (bytes: u, bytesPerRow: 4, bytesPerPixel: 2),
          (bytes: v, bytesPerRow: 4, bytesPerPixel: 2),
        ],
      );

      final rgb = cameraFrameToRgb(image);
      for (var i = 0; i < width * height; i++) {
        expect(rgb.rgb[i * 3], inInclusiveRange(253, 255));
        expect(rgb.rgb[i * 3 + 1], 0);
        expect(rgb.rgb[i * 3 + 2], 0);
      }
    });

    test('nv21 with two planes (VU interleaved)', () {
      const width = 2, height = 2;
      final y = Uint8List.fromList([128, 128, 128, 128]);
      // VU pairs: [V,U,V,U]
      final vu = Uint8List.fromList([128, 128, 128, 128]);
      final image = _cameraImage(
        group: ImageFormatGroup.nv21,
        width: width,
        height: height,
        planes: [
          (bytes: y, bytesPerRow: 2, bytesPerPixel: 1),
          (bytes: vu, bytesPerRow: 4, bytesPerPixel: 2),
        ],
      );

      final rgb = cameraFrameToRgb(image);
      for (var i = 0; i < width * height; i++) {
        expect(rgb.rgb[i * 3], 128);
        expect(rgb.rgb[i * 3 + 1], 128);
        expect(rgb.rgb[i * 3 + 2], 128);
      }
    });

    test('nv21 with a single interleaved buffer (camerax layout)', () {
      const width = 2, height = 2;
      final buffer = Uint8List(width * height + width); // 2x2 Y + 2x1 VU
      for (var i = 0; i < width * height; i++) {
        buffer[i] = 128;
      }
      // VU pairs
      buffer[4] = 128; // V
      buffer[5] = 128; // U
      final image = _cameraImage(
        group: ImageFormatGroup.nv21,
        width: width,
        height: height,
        planes: [
          (bytes: buffer, bytesPerRow: width, bytesPerPixel: 1),
        ],
      );

      final rgb = cameraFrameToRgb(image);
      for (var i = 0; i < width * height; i++) {
        expect(rgb.rgb[i * 3], 128);
        expect(rgb.rgb[i * 3 + 1], 128);
        expect(rgb.rgb[i * 3 + 2], 128);
      }
    });

    test('bgra8888 swaps to RGB', () {
      const width = 2, height = 1;
      final bgra = Uint8List.fromList([
        11, 22, 33, 255, // pixel 0: B=11 G=22 R=33
        44, 55, 66, 255, // pixel 1
      ]);
      final image = _cameraImage(
        group: ImageFormatGroup.bgra8888,
        width: width,
        height: height,
        planes: [
          (bytes: bgra, bytesPerRow: 8, bytesPerPixel: 4),
        ],
      );

      final rgb = cameraFrameToRgb(image);
      expect(rgb.rgb, [33, 22, 11, 66, 55, 44]);
    });

    test('rejects unsupported formats', () {
      final image = _cameraImage(
        group: ImageFormatGroup.unknown,
        width: 2,
        height: 2,
        planes: [
          (bytes: Uint8List(4), bytesPerRow: 4, bytesPerPixel: 1),
        ],
      );

      expect(() => cameraFrameToRgb(image), throwsUnsupportedError);
    });

    test('rejects undersized plane buffers', () {
      final image = _cameraImage(
        group: ImageFormatGroup.yuv420,
        width: 4,
        height: 4,
        planes: [
          (bytes: Uint8List(2), bytesPerRow: 4, bytesPerPixel: 1),
          (bytes: Uint8List(8), bytesPerRow: 4, bytesPerPixel: 1),
          (bytes: Uint8List(8), bytesPerRow: 4, bytesPerPixel: 1),
        ],
      );

      expect(() => cameraFrameToRgb(image), throwsArgumentError);
    });
  });

  group('decodeGalleryImage and processGalleryImage', () {
    test('decodes a PNG to RGB with correct dimensions', () {
      final image = img.Image(width: 3, height: 2);
      for (final p in image) {
        p.r = 200;
        p.g = 100;
        p.b = 50;
        p.a = 255;
      }
      final bytes = Uint8List.fromList(img.encodePng(image));

      final decoded = decodeGalleryImage(bytes);
      expect(decoded.width, 3);
      expect(decoded.height, 2);
      expect(decoded.rgb, hasLength(3 * 2 * 3));
      expect(decoded.rgb[0], 200);
      expect(decoded.rgb[1], 100);
      expect(decoded.rgb[2], 50);
    });

    test('rejects corrupted image data', () {
      final corrupt = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(() => decodeGalleryImage(corrupt), throwsArgumentError);
    });

    test('applies EXIF orientation 6 before resizing', () {
      // 8x4: left half red, right half blue. Orientation 6 rotates 90 CW, so
      // red ends up at the top of the decoded image.
      final image = img.Image(width: 8, height: 4);
      for (final p in image) {
        final blue = p.x >= 4;
        p.r = blue ? 0 : 255;
        p.g = 0;
        p.b = blue ? 255 : 0;
        p.a = 255;
      }
      image.exif.imageIfd.orientation = 6;
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 100));

      final decoded = decodeGalleryImage(bytes);
      expect(decoded.width, 4);
      expect(decoded.height, 8);

      // Top-left red, bottom-left blue after orientation baking (JPEG is
      // lossy; allow a few levels of drift).
      final topLeft = 0;
      final bottomLeft = (7 * 4) * 3;
      expect(decoded.rgb[topLeft], inInclusiveRange(250, 255));
      expect(decoded.rgb[topLeft + 2], lessThanOrEqualTo(5));
      expect(decoded.rgb[bottomLeft], lessThanOrEqualTo(5));
      expect(decoded.rgb[bottomLeft + 2], inInclusiveRange(250, 255));
    });

    test('processGalleryImage runs in an isolate and returns model input', () async {
      final image = img.Image(width: 16, height: 16);
      for (final p in image) {
        p.r = 180;
        p.g = 60;
        p.b = 90;
        p.a = 255;
      }
      final bytes = Uint8List.fromList(img.encodePng(image));

      final input = await processGalleryImage(bytes);
      expect(input.length, 224 * 224 * 3);
      expect(input[0], 180.0);
      expect(input[1], 60.0);
      expect(input[2], 90.0);
    });
  });
}