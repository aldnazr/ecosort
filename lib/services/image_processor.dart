import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageProcessor {
  static const int modelInputWidth = 320;
  static const int modelInputHeight = 320;

  static Float32List processGalleryImage(
    Uint8List imageBytes, {
    int targetWidth = modelInputWidth,
    int targetHeight = modelInputHeight,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ArgumentError('Failed to decode image bytes');
    }

    final oriented = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      oriented,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    final Float32List buffer = Float32List(targetWidth * targetHeight * 3);
    int bufferIdx = 0;

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final pixel = resized.getPixel(x, y);
        buffer[bufferIdx++] = pixel.rNormalized.toDouble();
        buffer[bufferIdx++] = pixel.gNormalized.toDouble();
        buffer[bufferIdx++] = pixel.bNormalized.toDouble();
      }
    }

    return buffer;
  }

  static Float32List processCameraImage(
    CameraImage cameraImage, {
    int rotation = 90,
    int targetWidth = modelInputWidth,
    int targetHeight = modelInputHeight,
  }) {
    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return _convertBgra8888(
        cameraImage,
        rotation: rotation,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
    } else {
      return _convertYuv420(
        cameraImage,
        rotation: rotation,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
    }
  }

  static Float32List _convertYuv420(
    CameraImage image, {
    required int rotation,
    required int targetWidth,
    required int targetHeight,
  }) {
    final Float32List buffer = Float32List(targetWidth * targetHeight * 3);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Uint8List yBytes = yPlane.bytes;
    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;

    final int srcW = image.width;
    final int srcH = image.height;

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    final int uRowStride = uPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;

    final int vRowStride = vPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    int outIdx = 0;

    for (int ty = 0; ty < targetHeight; ty++) {
      for (int tx = 0; tx < targetWidth; tx++) {
        int sx, sy;

        switch (rotation) {
          case 90:
            sx = (ty * srcW) ~/ targetHeight;
            sy = ((targetWidth - 1 - tx) * srcH) ~/ targetWidth;
            break;
          case 180:
            sx = ((targetWidth - 1 - tx) * srcW) ~/ targetWidth;
            sy = ((targetHeight - 1 - ty) * srcH) ~/ targetHeight;
            break;
          case 270:
            sx = ((targetHeight - 1 - ty) * srcW) ~/ targetHeight;
            sy = (tx * srcH) ~/ targetWidth;
            break;
          case 0:
          default:
            sx = (tx * srcW) ~/ targetWidth;
            sy = (ty * srcH) ~/ targetHeight;
            break;
        }

        if (sx < 0) sx = 0;
        if (sx >= srcW) sx = srcW - 1;
        if (sy < 0) sy = 0;
        if (sy >= srcH) sy = srcH - 1;

        final int yIndex = sy * yRowStride + sx * yPixelStride;
        final int uvX = sx >> 1;
        final int uvY = sy >> 1;
        final int uIndex = uvY * uRowStride + uvX * uPixelStride;
        final int vIndex = uvY * vRowStride + uvX * vPixelStride;

        final int yVal = yBytes[yIndex];
        final int uVal = uBytes[uIndex];
        final int vVal = vBytes[vIndex];

        // Standard BT.601 YUV to RGB conversion
        final double y = yVal.toDouble();
        final double u = uVal.toDouble() - 128.0;
        final double v = vVal.toDouble() - 128.0;

        double r = y + 1.402 * v;
        double g = y - 0.344136 * u - 0.714136 * v;
        double b = y + 1.772 * u;

        r = (r.clamp(0.0, 255.0)) / 255.0;
        g = (g.clamp(0.0, 255.0)) / 255.0;
        b = (b.clamp(0.0, 255.0)) / 255.0;

        buffer[outIdx++] = r;
        buffer[outIdx++] = g;
        buffer[outIdx++] = b;
      }
    }

    return buffer;
  }

  static Float32List _convertBgra8888(
    CameraImage image, {
    required int rotation,
    required int targetWidth,
    required int targetHeight,
  }) {
    final Float32List buffer = Float32List(targetWidth * targetHeight * 3);
    final Plane plane = image.planes[0];
    final Uint8List bytes = plane.bytes;
    final int rowStride = plane.bytesPerRow;
    final int pixelStride = plane.bytesPerPixel ?? 4;
    final int srcW = image.width;
    final int srcH = image.height;

    int outIdx = 0;

    for (int ty = 0; ty < targetHeight; ty++) {
      for (int tx = 0; tx < targetWidth; tx++) {
        int sx, sy;

        switch (rotation) {
          case 90:
            sx = (ty * srcW) ~/ targetHeight;
            sy = ((targetWidth - 1 - tx) * srcH) ~/ targetWidth;
            break;
          case 180:
            sx = ((targetWidth - 1 - tx) * srcW) ~/ targetWidth;
            sy = ((targetHeight - 1 - ty) * srcH) ~/ targetHeight;
            break;
          case 270:
            sx = ((targetHeight - 1 - ty) * srcW) ~/ targetHeight;
            sy = (tx * srcH) ~/ targetWidth;
            break;
          case 0:
          default:
            sx = (tx * srcW) ~/ targetWidth;
            sy = (ty * srcH) ~/ targetHeight;
            break;
        }

        if (sx < 0) sx = 0;
        if (sx >= srcW) sx = srcW - 1;
        if (sy < 0) sy = 0;
        if (sy >= srcH) sy = srcH - 1;

        final int pixelIndex = sy * rowStride + sx * pixelStride;
        final double b = bytes[pixelIndex] / 255.0;
        final double g = bytes[pixelIndex + 1] / 255.0;
        final double r = bytes[pixelIndex + 2] / 255.0;

        buffer[outIdx++] = r;
        buffer[outIdx++] = g;
        buffer[outIdx++] = b;
      }
    }

    return buffer;
  }
}
