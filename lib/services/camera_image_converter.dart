import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Bộ chuyển đổi hiệu năng cao giữa CameraImage và img.Image
class CameraImageConverter {
  /// Cắt trực tiếp vùng khuôn mặt từ CameraImage và chuyển sang ảnh RGB 112x112
  /// Tối ưu chỉ chuyển đổi vùng khuôn mặt thay vì chuyển đổi toàn bộ khung hình
  static img.Image cropFaceToImage112({
    required CameraImage cameraImage,
    required Rect boundingBox,
    int targetSize = 112,
  }) {
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    // Thêm lề 12% xung quanh bounding box
    final marginX = boundingBox.width * 0.12;
    final marginY = boundingBox.height * 0.12;

    final left = (boundingBox.left - marginX).clamp(0.0, (imageWidth - 1).toDouble()).toInt();
    final top = (boundingBox.top - marginY).clamp(0.0, (imageHeight - 1).toDouble()).toInt();
    final right = (boundingBox.right + marginX).clamp(1.0, imageWidth.toDouble()).toInt();
    final bottom = (boundingBox.bottom + marginY).clamp(1.0, imageHeight.toDouble()).toInt();

    final cropWidth = (right - left).clamp(1, imageWidth);
    final cropHeight = (bottom - top).clamp(1, imageHeight);

    final croppedImage = img.Image(width: cropWidth, height: cropHeight);

    if (Platform.isAndroid && cameraImage.format.group == ImageFormatGroup.nv21) {
      _convertNv21Region(
        cameraImage: cameraImage,
        croppedImage: croppedImage,
        cropLeft: left,
        cropTop: top,
        cropWidth: cropWidth,
        cropHeight: cropHeight,
      );
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      _convertBgra8888Region(
        cameraImage: cameraImage,
        croppedImage: croppedImage,
        cropLeft: left,
        cropTop: top,
        cropWidth: cropWidth,
        cropHeight: cropHeight,
      );
    } else {
      // YUV420 standard multi-plane fallback
      _convertYuv420Region(
        cameraImage: cameraImage,
        croppedImage: croppedImage,
        cropLeft: left,
        cropTop: top,
        cropWidth: cropWidth,
        cropHeight: cropHeight,
      );
    }

    // Resize về kích thước chuẩn 112x112 cho MobileFaceNet
    if (cropWidth == targetSize && cropHeight == targetSize) {
      return croppedImage;
    }
    return img.copyResize(croppedImage, width: targetSize, height: targetSize);
  }

  static void _convertNv21Region({
    required CameraImage cameraImage,
    required img.Image croppedImage,
    required int cropLeft,
    required int cropTop,
    required int cropWidth,
    required int cropHeight,
  }) {
    final yPlane = cameraImage.planes[0];
    final uvPlane = cameraImage.planes.length > 1 ? cameraImage.planes[1] : null;

    final yBytes = yPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;

    final uvBytes = uvPlane?.bytes;
    final uvRowStride = uvPlane?.bytesPerRow ?? yRowStride;
    final uvPixelStride = uvPlane?.bytesPerPixel ?? 2;

    for (int y = 0; y < cropHeight; y++) {
      final srcY = cropTop + y;
      final yRowOffset = srcY * yRowStride;
      final uvRowOffset = (srcY >> 1) * uvRowStride;

      for (int x = 0; x < cropWidth; x++) {
        final srcX = cropLeft + x;
        final yVal = yBytes[yRowOffset + srcX];

        int uVal = 128;
        int vVal = 128;

        if (uvBytes != null) {
          final uvOffset = uvRowOffset + (srcX >> 1) * uvPixelStride;
          if (uvOffset + 1 < uvBytes.length) {
            // NV21 stores VU interleaved
            vVal = uvBytes[uvOffset];
            uVal = uvBytes[uvOffset + 1];
          }
        }

        final r = (yVal + 1.402 * (vVal - 128)).round().clamp(0, 255);
        final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).round().clamp(0, 255);
        final b = (yVal + 1.772 * (uVal - 128)).round().clamp(0, 255);

        croppedImage.setPixelRgb(x, y, r, g, b);
      }
    }
  }

  static void _convertBgra8888Region({
    required CameraImage cameraImage,
    required img.Image croppedImage,
    required int cropLeft,
    required int cropTop,
    required int cropWidth,
    required int cropHeight,
  }) {
    final plane = cameraImage.planes[0];
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final pixelStride = plane.bytesPerPixel ?? 4;

    for (int y = 0; y < cropHeight; y++) {
      final srcY = cropTop + y;
      final rowOffset = srcY * rowStride;

      for (int x = 0; x < cropWidth; x++) {
        final srcX = cropLeft + x;
        final offset = rowOffset + srcX * pixelStride;

        final b = bytes[offset];
        final g = bytes[offset + 1];
        final r = bytes[offset + 2];

        croppedImage.setPixelRgb(x, y, r, g, b);
      }
    }
  }

  static void _convertYuv420Region({
    required CameraImage cameraImage,
    required img.Image croppedImage,
    required int cropLeft,
    required int cropTop,
    required int cropWidth,
    required int cropHeight,
  }) {
    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes.length > 1 ? cameraImage.planes[1] : yPlane;
    final vPlane = cameraImage.planes.length > 2 ? cameraImage.planes[2] : yPlane;

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;

    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < cropHeight; y++) {
      final srcY = cropTop + y;
      final yRowOffset = srcY * yRowStride;
      final uvY = srcY >> 1;

      for (int x = 0; x < cropWidth; x++) {
        final srcX = cropLeft + x;
        final uvX = srcX >> 1;

        final yVal = yBytes[yRowOffset + srcX];
        final uVal = uBytes[uvY * uRowStride + uvX * uPixelStride];
        final vVal = vBytes[uvY * vRowStride + uvX * vPixelStride];

        final r = (yVal + 1.402 * (vVal - 128)).round().clamp(0, 255);
        final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).round().clamp(0, 255);
        final b = (yVal + 1.772 * (uVal - 128)).round().clamp(0, 255);

        croppedImage.setPixelRgb(x, y, r, g, b);
      }
    }
  }
}
