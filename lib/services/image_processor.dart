import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:image/image.dart' as img;

const int modelInputSize = 224;

Future<Float32List> processGalleryImage(Uint8List bytes) {
  return Isolate.run(() {
    final decoded = decodeGalleryImage(bytes);
    return rgbToModelInput(decoded.rgb, decoded.width, decoded.height);
  });
}

Future<Float32List> processCameraImage({
  required CameraImage image,
  required int rotation,
}) {
  return Isolate.run(() {
    final rgb = cameraFrameToRgb(image);
    final rotated = rotateRgb(rgb.rgb, rgb.width, rgb.height, rotation);
    return rgbToModelInput(rotated.rgb, rotated.width, rotated.height);
  });
}

({Uint8List rgb, int width, int height}) decodeGalleryImage(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw ArgumentError('Unsupported or corrupted image data.');
  }
  // Respect EXIF orientation before resizing.
  final baked = img.bakeOrientation(image);
  return (
    rgb: baked.getBytes(order: img.ChannelOrder.rgb),
    width: baked.width,
    height: baked.height,
  );
}

/// Degrees to rotate the raw camera buffer clockwise so pixels become
/// upright, from the sensor orientation, the current device orientation and
/// the lens direction. Front-camera compensation is inverted, mirroring the
/// camera plugin's own capture rotation math.
int computeFrameRotation({
  required int sensorOrientation,
  required DeviceOrientation deviceOrientation,
  required CameraLensDirection lensDirection,
}) {
  final int deviceAngle;
  switch (deviceOrientation) {
    case DeviceOrientation.portraitUp:
      deviceAngle = 0;
    case DeviceOrientation.landscapeRight:
      deviceAngle = 90;
    case DeviceOrientation.portraitDown:
      deviceAngle = 180;
    case DeviceOrientation.landscapeLeft:
      deviceAngle = 270;
  }
  if (lensDirection == CameraLensDirection.front) {
    return (sensorOrientation - deviceAngle + 360) % 360;
  }
  return (sensorOrientation + deviceAngle) % 360;
}

/// Converts a plugin camera frame to interleaved RGB. Handles YUV420
/// (planar or semi-planar), NV21 (single interleaved chroma plane) and
/// BGRA8888, honoring each plane's row and pixel strides. Anything else is
/// rejected.
({Uint8List rgb, int width, int height}) cameraFrameToRgb(CameraImage image) {
  final width = image.width;
  final height = image.height;
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Camera frame has invalid dimensions: ${image.width}x${image.height}.');
  }

  switch (image.format.group) {
    case ImageFormatGroup.yuv420:
    case ImageFormatGroup.nv21:
      return _yuvToRgb(image);
    case ImageFormatGroup.bgra8888:
      return _bgraToRgb(image);
    default:
      throw UnsupportedError(
        'Unsupported camera frame format: ${image.format.group}. '
        'Expected yuv420, nv21 or bgra8888.',
      );
  }
}

({Uint8List rgb, int width, int height}) _yuvToRgb(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final planes = image.planes;
  if (planes.isEmpty) {
    throw ArgumentError('Camera frame has no planes.');
  }
  final yPlane = planes[0];
  final minLumaLength = (height - 1) * yPlane.bytesPerRow + width;
  if (yPlane.bytes.length < minLumaLength) {
    throw ArgumentError('Luma plane buffer is too small.');
  }

  final out = Uint8List(width * height * 3);
  final chromaWidth = (width + 1) ~/ 2;
  final chromaHeight = (height + 1) ~/ 2;

  if (planes.length >= 3) {
    final uPlane = planes[1];
    final vPlane = planes[2];
    final chromaArea = chromaWidth * chromaHeight;
    // iOS reports null pixel stride; infer interleaving from buffer size.
    final uPixelStride = uPlane.bytesPerPixel ??
        (uPlane.bytes.length >= chromaArea * 2 ? 2 : 1);
    final vPixelStride = vPlane.bytesPerPixel ??
        (vPlane.bytes.length >= chromaArea * 2 ? 2 : 1);

    final minULength = (chromaHeight - 1) * uPlane.bytesPerRow +
        (chromaWidth - 1) * uPixelStride +
        1;
    final minVLength = (chromaHeight - 1) * vPlane.bytesPerRow +
        (chromaWidth - 1) * vPixelStride +
        1;
    if (uPlane.bytes.length < minULength || vPlane.bytes.length < minVLength) {
      throw ArgumentError('Chroma plane buffer is too small.');
    }

    _convertYuv(
      out,
      width,
      height,
      yBytes: yPlane.bytes,
      yRowStride: yPlane.bytesPerRow,
      uBytes: uPlane.bytes,
      uRowStride: uPlane.bytesPerRow,
      uPixelStride: uPixelStride,
      vBytes: vPlane.bytes,
      vRowStride: vPlane.bytesPerRow,
      vPixelStride: vPixelStride,
    );
  } else if (planes.length == 1 && image.format.group == ImageFormatGroup.nv21) {
    // Single-buffer NV21 (camera_android_camerax): Y plane followed by
    // interleaved VU pairs.
    final buffer = planes.single.bytes;
    if (buffer.length < width * height + chromaWidth * chromaHeight * 2) {
      throw ArgumentError('NV21 buffer is too small.');
    }
    final lumaSize = width * height;
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width; col++) {
        final yValue = buffer[row * yPlane.bytesPerRow + col];
        final uvIndex =
            lumaSize + (row ~/ 2) * chromaWidth + (col ~/ 2) * 2;
        final vValue = buffer[uvIndex];
        final uValue = buffer[uvIndex + 1];
        _writeYuvPixel(out, (row * width + col) * 3, yValue, uValue, vValue);
      }
    }
  } else if (planes.length == 2) {
    // NV21: interleaved VU pairs in the second plane.
    final vuPlane = planes[1];
    final vuRowStride = vuPlane.bytesPerRow;
    final vuPixelStride = vuPlane.bytesPerPixel ?? 2;
    final vuTrailingOffset = vuPixelStride == 1 ? chromaWidth : 1;
    final minVuLength = (chromaHeight - 1) * vuRowStride +
        (chromaWidth - 1) * vuPixelStride +
        vuTrailingOffset +
        1;
    if (vuPlane.bytes.length < minVuLength) {
      throw ArgumentError('Chroma plane buffer is too small.');
    }
    final vu = vuPlane.bytes;
    final y = yPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width; col++) {
        final yValue = y[row * yRowStride + col];
        final uvIndex =
            (row ~/ 2) * vuRowStride + (col ~/ 2) * vuPixelStride;
        final vValue = vu[uvIndex];
        final uValue = vuPixelStride == 1
            ? vu[uvIndex + chromaWidth]
            : vu[uvIndex + 1];
        final o = (row * width + col) * 3;
        _writeYuvPixel(out, o, yValue, uValue, vValue);
      }
    }
  } else {
    throw ArgumentError(
      'Camera frame has ${planes.length} plane(s); cannot decode YUV.',
    );
  }
  return (rgb: out, width: width, height: height);
}

void _convertYuv(
  Uint8List out,
  int width,
  int height, {
  required Uint8List yBytes,
  required int yRowStride,
  required Uint8List uBytes,
  required int uRowStride,
  required int uPixelStride,
  required Uint8List vBytes,
  required int vRowStride,
  required int vPixelStride,
}) {
  for (var row = 0; row < height; row++) {
    for (var col = 0; col < width; col++) {
      final yValue = yBytes[row * yRowStride + col];
      final uValue = uBytes[(row ~/ 2) * uRowStride + (col ~/ 2) * uPixelStride];
      final vValue = vBytes[(row ~/ 2) * vRowStride + (col ~/ 2) * vPixelStride];
      _writeYuvPixel(out, (row * width + col) * 3, yValue, uValue, vValue);
    }
  }
}

// BT.601 full-range YUV to RGB, matching the common TFLite camera examples.
void _writeYuvPixel(
  Uint8List out,
  int offset,
  int y,
  int u,
  int v,
) {
  final r = (y + 1.402 * (v - 128)).round();
  final g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round();
  final b = (y + 1.772 * (u - 128)).round();
  out[offset] = r.clamp(0, 255);
  out[offset + 1] = g.clamp(0, 255);
  out[offset + 2] = b.clamp(0, 255);
}

({Uint8List rgb, int width, int height}) _bgraToRgb(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final plane = image.planes.single;
  final bytesPerPixel = plane.bytesPerPixel ?? 4;
  if (bytesPerPixel != 4) {
    throw ArgumentError(
      'Unexpected BGRA pixel stride: $bytesPerPixel.',
    );
  }
  final minBgraLength = (height - 1) * plane.bytesPerRow + width * 4;
  if (plane.bytes.length < minBgraLength) {
    throw ArgumentError('BGRA plane buffer is too small.');
  }
  final out = Uint8List(width * height * 3);
  for (var row = 0; row < height; row++) {
    var src = row * plane.bytesPerRow;
    var dst = row * width * 3;
    for (var col = 0; col < width; col++) {
      out[dst] = plane.bytes[src + 2];
      out[dst + 1] = plane.bytes[src + 1];
      out[dst + 2] = plane.bytes[src];
      src += 4;
      dst += 3;
    }
  }
  return (rgb: out, width: width, height: height);
}

/// Rotates interleaved RGB clockwise by [degrees] (multiple of 90).
({Uint8List rgb, int width, int height}) rotateRgb(
  Uint8List rgb,
  int width,
  int height,
  int degrees,
) {
  if (rgb.length != width * height * 3) {
    throw ArgumentError('RGB buffer length mismatch.');
  }
  final normalized = ((degrees % 360) + 360) % 360;
  switch (normalized) {
    case 0:
      return (rgb: rgb, width: width, height: height);
    case 180:
      final out = Uint8List(rgb.length);
      for (var row = 0; row < height; row++) {
        for (var col = 0; col < width; col++) {
          final src = ((height - 1 - row) * width + (width - 1 - col)) * 3;
          final dst = (row * width + col) * 3;
          out[dst] = rgb[src];
          out[dst + 1] = rgb[src + 1];
          out[dst + 2] = rgb[src + 2];
        }
      }
      return (rgb: out, width: width, height: height);
    case 90:
    case 270:
      final newWidth = height;
      final newHeight = width;
      final out = Uint8List(rgb.length);
      for (var row = 0; row < newHeight; row++) {
        for (var col = 0; col < newWidth; col++) {
          // CW 90: dst(x', y') = src(y', h - 1 - x').
          // CW 270 (CCW 90): dst(x', y') = src(w - 1 - y', x').
          final srcX = normalized == 90 ? row : width - 1 - row;
          final srcY = normalized == 90 ? height - 1 - col : col;
          final src = (srcY * width + srcX) * 3;
          final dst = (row * newWidth + col) * 3;
          out[dst] = rgb[src];
          out[dst + 1] = rgb[src + 1];
          out[dst + 2] = rgb[src + 2];
        }
      }
      return (rgb: out, width: newWidth, height: newHeight);
    default:
      throw ArgumentError('Rotation must be a multiple of 90 degrees.');
  }
}

/// Resizes interleaved RGB to the model's 224x224 input with bilinear
/// sampling and packs NHWC float32 values 0..255 (no normalization; the
/// model embeds mean/std). No crop, no letterbox: the whole image stretches.
Float32List rgbToModelInput(Uint8List rgb, int width, int height) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Invalid RGB dimensions: ${width}x$height.');
  }
  if (rgb.length != width * height * 3) {
    throw ArgumentError(
      'RGB buffer length mismatch: expected ${width * height * 3}, '
      'got ${rgb.length}.',
    );
  }

  final size = modelInputSize;
  final out = Float32List(size * size * 3);
  final fx = width / size;
  final fy = height / size;

  for (var oy = 0; oy < size; oy++) {
    var sy = (oy + 0.5) * fy - 0.5;
    if (sy < 0) sy = 0;
    if (sy > height - 1) sy = height - 1;
    final y0 = sy.floor();
    final y1 = math.min(y0 + 1, height - 1);
    final wy = sy - y0;
    final rowBase = oy * size * 3;

    for (var ox = 0; ox < size; ox++) {
      var sx = (ox + 0.5) * fx - 0.5;
      if (sx < 0) sx = 0;
      if (sx > width - 1) sx = width - 1;
      final x0 = sx.floor();
      final x1 = math.min(x0 + 1, width - 1);
      final wx = sx - x0;

      final p00 = (y0 * width + x0) * 3;
      final p01 = (y0 * width + x1) * 3;
      final p10 = (y1 * width + x0) * 3;
      final p11 = (y1 * width + x1) * 3;
      final dst = rowBase + ox * 3;

      for (var c = 0; c < 3; c++) {
        out[dst + c] = rgb[p00 + c] * (1 - wy) * (1 - wx) +
            rgb[p01 + c] * (1 - wy) * wx +
            rgb[p10 + c] * wy * (1 - wx) +
            rgb[p11 + c] * wy * wx;
      }
    }
  }
  return out;
}