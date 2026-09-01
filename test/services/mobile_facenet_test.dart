import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_toilet_kiosk/services/face_embedding_service.dart';
import 'package:smart_toilet_kiosk/services/mobile_facenet_service.dart';

void main() {
  group('MobileFaceNetService Tests', () {
    late MobileFaceNetService service;

    setUp(() async {
      service = MobileFaceNetService();
      // Chạy init (sẽ tự động fallback mượt mà nếu thiếu native C++ library trong test environment)
      await service.init();
    });

    tearDown(() {
      service.dispose();
    });

    test('Predict produces normalized 192-dimensional vector', () {
      // Tạo ảnh giả lập 112x112 RGB
      final dummyFace = img.Image(width: 112, height: 112);
      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          dummyFace.setPixelRgb(x, y, 200, 150, 120); // Màu da mặt
        }
      }

      final vector = service.predict(dummyFace, fallbackSeed: 'test_face_01');
      expect(vector.length, equals(192));

      // L2 norm must equal 1.0
      double sumSquares = 0.0;
      for (final val in vector) {
        sumSquares += val * val;
      }
      expect(sumSquares, closeTo(1.0, 0.01));
    });

    test('Identical face predictions yield Cosine Similarity near 1.0', () {
      final faceImage1 = img.Image(width: 112, height: 112);
      final faceImage2 = img.Image(width: 112, height: 112);

      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          faceImage1.setPixelRgb(x, y, 180, 130, 110);
          faceImage2.setPixelRgb(x, y, 180, 130, 110);
        }
      }

      final v1 = service.predict(faceImage1, fallbackSeed: 'same_person');
      final v2 = service.predict(faceImage2, fallbackSeed: 'same_person');

      final sim = FaceEmbeddingService.cosineSimilarity(v1, v2);
      expect(sim, closeTo(1.0, 0.001));
    });

    test('cropAndPreprocessFace correctly crops and resizes to 112x112', () {
      final fullImage = img.Image(width: 640, height: 480);
      const faceBox = Rect.fromLTWH(200, 100, 150, 180);

      final cropped = MobileFaceNetService.cropAndPreprocessFace(fullImage, faceBox);
      expect(cropped.width, equals(112));
      expect(cropped.height, equals(112));
    });
  });
}
