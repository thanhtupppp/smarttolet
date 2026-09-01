import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_embedding_service.dart';
import 'mobile_facenet_service.dart';
import 'camera_image_converter.dart';

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

/// Service tích hợp Google ML Kit Face Detection và Deep Learning MobileFaceNet TFLite
class FaceDetectorService {
  late final FaceDetector _detector;
  late final MobileFaceNetService _mobileFaceNet;
  bool _isProcessing = false;

  FaceDetectorService({MobileFaceNetService? mobileFaceNet}) {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
        enableClassification: true, // Bật phân loại mắt mở/nhắm để phát hiện người thật
        enableTracking: false,
        minFaceSize: 0.18, // Chỉ nhận khuôn mặt đủ lớn đứng trước Kiosk (~35cm - 1.2m)
        performanceMode: FaceDetectorMode.accurate, // Chế độ chính xác cao, loại bỏ tối đa false positive
      ),
    );
    _mobileFaceNet = mobileFaceNet ?? MobileFaceNetService();
    _mobileFaceNet.init();
  }

  MobileFaceNetService get mobileFaceNet => _mobileFaceNet;

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

      // BỘ LỌC 1: Góc quay đầu (Head Pose Gate) - Chỉ nhận khuôn mặt nhìn thẳng vào camera
      final validFrontalFaces = faces.where((f) {
        final yaw = f.headEulerAngleY ?? 0;   // Quay trái / phải
        final roll = f.headEulerAngleZ ?? 0;  // Nghiêng đầu sang vai
        final pitch = f.headEulerAngleX ?? 0; // Ngước lên / cúi xuống
        return yaw.abs() <= 20 && roll.abs() <= 16 && pitch.abs() <= 20;
      }).toList();

      if (validFrontalFaces.isEmpty) return null;

      // Lấy khuôn mặt lớn nhất ở vị trí trung tâm
      final mainFace = validFrontalFaces.reduce((a, b) =>
          (a.boundingBox.width * a.boundingBox.height) >
                  (b.boundingBox.width * b.boundingBox.height)
              ? a
              : b);

      // BỘ LỌC 2: Kiểm tra người thật qua trạng thái mở mắt (Eye Open Liveness Gate)
      final leftEyeOpen = mainFace.leftEyeOpenProbability;
      final rightEyeOpen = mainFace.rightEyeOpenProbability;
      if (leftEyeOpen != null && rightEyeOpen != null) {
        // Cả 2 mắt phải mở rõ (chống mắt nhắm, ảnh tĩnh mắt nhắm, hoặc vật thể tròn không có mắt)
        if (leftEyeOpen < 0.30 || rightEyeOpen < 0.30) {
          return null;
        }
      }

      final features = _extractFaceFeatures(mainFace);
      if (features == null) return null;

      // BƯỚC 5: Cắt trực tiếp vùng khuôn mặt sang ảnh 112x112 RGB và đưa vào mạng MobileFaceNet TFLite
      final faceImage112 = CameraImageConverter.cropFaceToImage112(
        cameraImage: image,
        boundingBox: mainFace.boundingBox,
      );

      final deepEmbedding = _mobileFaceNet.predict(
        faceImage112,
        fallbackSeed: features.faceFeatureSeed,
      );

      return DetectedFaceInfo(
        boundingBox: features.boundingBox,
        headEulerAngleY: features.headEulerAngleY,
        headEulerAngleZ: features.headEulerAngleZ,
        boundingBoxRatio: features.boundingBoxRatio,
        eyeDistanceRatio: features.eyeDistanceRatio,
        mouthWidthRatio: features.mouthWidthRatio,
        noseToMouthRatio: features.noseToMouthRatio,
        eyeToNoseRatio: features.eyeToNoseRatio,
        cheekWidthRatio: features.cheekWidthRatio,
        faceSymmetryRatio: features.faceSymmetryRatio,
        faceFeatureSeed: features.faceFeatureSeed,
        embedding192d: deepEmbedding,
      );
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
  DetectedFaceInfo? _extractFaceFeatures(Face face) {
    final box = face.boundingBox;
    final boxWidth = box.width > 0 ? box.width : 1.0;
    final boxHeight = box.height > 0 ? box.height : 1.0;
    final boxRatio = boxHeight / boxWidth;

    // BỘ LỌC 3: Tỷ lệ nhân trắc học hình dáng mặt người (Aspect Ratio Gate)
    // Mặt người thật luôn có chiều cao > chiều ngang (tỷ lệ chuẩn từ 1.08 đến 1.70).
    // Vật tròn (cốc, nắp chai ~ 1.0) hoặc vật dài (chai lọ, hộp > 1.8 hoặc dẹt < 1.0) bị loại ngay!
    if (boxRatio < 1.06 || boxRatio > 1.75) {
      return null;
    }

    // 1. Tọa độ các điểm mốc sinh trắc học
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final noseBase = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;

    // BỘ LỌC 4: Toàn vẹn cấu trúc giải phẫu học (Anatomical Integrity Check)
    // BẮT BUỘC phải có đủ 2 mắt, sống mũi và khóe miệng. Không cho phép fallback giá trị giả!
    if (leftEye == null || rightEye == null || noseBase == null || leftMouth == null || rightMouth == null) {
      return null;
    }

    // Mắt phải ở trên mũi, và mũi phải ở trên miệng
    final eyesCenterY = (leftEye.y + rightEye.y) / 2.0;
    final mouthCenterY = (leftMouth.y + rightMouth.y) / 2.0;
    if (eyesCenterY >= noseBase.y || noseBase.y >= mouthCenterY) {
      return null; // Thứ tự không gian sai lệch so với khuôn mặt người
    }

    // 2. Tính khoảng cách 2 mắt / bề ngang mặt
    final eyeDist = (rightEye.x - leftEye.x).abs();
    final eyeDistanceRatio = (eyeDist / boxWidth).clamp(0.2, 0.8);

    // 3. Tính bề rộng khuôn miệng / khoảng cách 2 mắt
    final mDist = (rightMouth.x - leftMouth.x).abs();
    final mouthWidthRatio = eyeDist > 0 ? (mDist / eyeDist).clamp(0.3, 1.8) : 0.9;

    // 4. Tính khoảng cách mũi đến miệng / chiều cao mặt
    double noseToMouthRatio = 0.25;
    if (bottomMouth != null) {
      final nmDist = (bottomMouth.y - noseBase.y).abs();
      noseToMouthRatio = (nmDist / boxHeight).clamp(0.1, 0.6);
    }

    // 5. Tính khoảng cách từ mắt đến mũi / chiều cao mặt
    final enDist = (noseBase.y - eyesCenterY).abs();
    final eyeToNoseRatio = (enDist / boxHeight).clamp(0.1, 0.7);

    // 6. Tính khoảng cách 2 xương gò má / bề ngang mặt
    double cheekWidthRatio = 0.85;
    if (leftCheek != null && rightCheek != null) {
      final cDist = (rightCheek.x - leftCheek.x).abs();
      cheekWidthRatio = (cDist / boxWidth).clamp(0.4, 1.2);
    }

    // 7. Tính tỉ lệ đối xứng tâm mặt
    final leftDist = (noseBase.x - leftEye.x).abs();
    final rightDist = (rightEye.x - noseBase.x).abs();
    final faceSymmetryRatio = rightDist > 0 ? (leftDist / rightDist).clamp(0.5, 2.0) : 1.0;

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
    _mobileFaceNet.dispose();
  }
}
