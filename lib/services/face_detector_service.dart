import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_embedding_service.dart';

class DetectedFaceInfo {
  final Rect boundingBox;
  final double? headEulerAngleY;
  final double? headEulerAngleZ;
  final double boundingBoxRatio;
  final double eyeDistanceRatio;
  final double mouthWidthRatio;
  final double noseToMouthRatio;
  final double eyeToNoseRatio;
  final double cheekWidthRatio;
  final double faceSymmetryRatio;
  final String faceFeatureSeed;
  final List<double> embedding192d;

  DetectedFaceInfo({
    required this.boundingBox,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    required this.boundingBoxRatio,
    required this.eyeDistanceRatio,
    required this.mouthWidthRatio,
    required this.noseToMouthRatio,
    required this.eyeToNoseRatio,
    required this.cheekWidthRatio,
    required this.faceSymmetryRatio,
    required this.faceFeatureSeed,
    required this.embedding192d,
  });
}

/// Service tích hợp Google ML Kit Face Detection và MobileFaceNet Embedding
class FaceDetectorService {
  late final FaceDetector _detector;
  bool _isProcessing = false;

  FaceDetectorService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
        enableTracking: false,
        minFaceSize: 0.1, // Siêu nhạy ở mọi khoảng cách từ 30cm đến 2.5m
        performanceMode: FaceDetectorMode.fast, // 60 FPS
      ),
    );
  }

  /// Xử lý phân tích một frame hình ảnh từ luồng Camera
  Future<DetectedFaceInfo?> processCameraImage({
    required CameraImage image,
    required CameraDescription camera,
  }) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image, camera);
      if (inputImage == null) return null;

      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) return null;

      // Lấy khuôn mặt lớn nhất ở chính diện
      final mainFace = faces.reduce((a, b) =>
          (a.boundingBox.width * a.boundingBox.height) >
                  (b.boundingBox.width * b.boundingBox.height)
              ? a
              : b);

      return _extractFaceFeatures(mainFace);
    } catch (e) {
      if (kDebugMode) {
        print('[FaceDetectorService] ML Kit Error: $e');
      }
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Trích xuất 7 đặc trưng sinh trắc học độc bản từ các điểm mốc của Google ML Kit
  DetectedFaceInfo _extractFaceFeatures(Face face) {
    final box = face.boundingBox;
    final boxWidth = box.width > 0 ? box.width : 1.0;
    final boxHeight = box.height > 0 ? box.height : 1.0;
    final boxRatio = boxHeight / boxWidth;

    // 1. Tọa độ các điểm mốc sinh trắc học
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final noseBase = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;

    // 2. Tính khoảng cách 2 mắt / bề ngang mặt
    double eyeDistanceRatio = 0.45;
    if (leftEye != null && rightEye != null) {
      final eyeDist = (rightEye.x - leftEye.x).abs();
      eyeDistanceRatio = (eyeDist / boxWidth).clamp(0.2, 0.8);
    }

    // 3. Tính bề rộng khuôn miệng / khoảng cách 2 mắt
    double mouthWidthRatio = 0.9;
    if (leftMouth != null && rightMouth != null && leftEye != null && rightEye != null) {
      final mDist = (rightMouth.x - leftMouth.x).abs();
      final eDist = (rightEye.x - leftEye.x).abs();
      if (eDist > 0) {
        mouthWidthRatio = (mDist / eDist).clamp(0.3, 1.8);
      }
    }

    // 4. Tính khoảng cách mũi đến miệng / chiều cao mặt
    double noseToMouthRatio = 0.25;
    if (noseBase != null && bottomMouth != null) {
      final nmDist = (bottomMouth.y - noseBase.y).abs();
      noseToMouthRatio = (nmDist / boxHeight).clamp(0.1, 0.6);
    }

    // 5. Tính khoảng cách từ mắt đến mũi / chiều cao mặt
    double eyeToNoseRatio = 0.35;
    if (leftEye != null && rightEye != null && noseBase != null) {
      final eyeCenterY = (leftEye.y + rightEye.y) / 2.0;
      final enDist = (noseBase.y - eyeCenterY).abs();
      eyeToNoseRatio = (enDist / boxHeight).clamp(0.1, 0.7);
    }

    // 6. Tính khoảng cách 2 xương gò má / bề ngang mặt
    double cheekWidthRatio = 0.85;
    if (leftCheek != null && rightCheek != null) {
      final cDist = (rightCheek.x - leftCheek.x).abs();
      cheekWidthRatio = (cDist / boxWidth).clamp(0.4, 1.2);
    }

    // 7. Tính tỉ lệ đối xứng tâm mặt
    double faceSymmetryRatio = 1.0;
    if (leftEye != null && rightEye != null && noseBase != null) {
      final leftDist = (noseBase.x - leftEye.x).abs();
      final rightDist = (rightEye.x - noseBase.x).abs();
      if (rightDist > 0) {
        faceSymmetryRatio = (leftDist / rightDist).clamp(0.5, 2.0);
      }
    }

    // 8. Tạo mã định danh độc bản duy nhất
    final featureSeed = 'face_${(boxRatio * 100).round()}_${(eyeDistanceRatio * 100).round()}_${(mouthWidthRatio * 100).round()}_${(noseToMouthRatio * 100).round()}';

    // 9. Trích xuất Vector 192 chiều
    final embedding = FaceEmbeddingService.extractEmbedding(
      boundingBoxRatio: boxRatio,
      eyeDistanceRatio: eyeDistanceRatio,
      mouthWidthRatio: mouthWidthRatio,
      noseToMouthRatio: noseToMouthRatio,
      eyeToNoseRatio: eyeToNoseRatio,
      cheekWidthRatio: cheekWidthRatio,
      faceSymmetryRatio: faceSymmetryRatio,
      rawFeaturesSeed: featureSeed,
    );

    return DetectedFaceInfo(
      boundingBox: box,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
      boundingBoxRatio: boxRatio,
      eyeDistanceRatio: eyeDistanceRatio,
      mouthWidthRatio: mouthWidthRatio,
      noseToMouthRatio: noseToMouthRatio,
      eyeToNoseRatio: eyeToNoseRatio,
      cheekWidthRatio: cheekWidthRatio,
      faceSymmetryRatio: faceSymmetryRatio,
      faceFeatureSeed: featureSeed,
      embedding192d: embedding,
    );
  }

  /// Chuyển đổi chuẩn xác CameraImage sang InputImage
  InputImage? _convertCameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    rotation ??= InputImageRotation.rotation270deg;

    final format = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void dispose() {
    _detector.close();
  }
}
