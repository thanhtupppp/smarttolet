import 'package:flutter_test/flutter_test.dart';
import 'package:smart_toilet_kiosk/services/face_embedding_service.dart';
import 'package:smart_toilet_kiosk/services/voice_prompt_service.dart';

void main() {
  group('FaceEmbeddingService Tests', () {
    test('Calculates exact cosine similarity for identical and orthogonal vectors', () {
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [1.0, 0.0, 0.0];
      final v3 = [0.0, 1.0, 0.0];

      expect(FaceEmbeddingService.cosineSimilarity(v1, v2), closeTo(1.0, 0.0001));
      expect(FaceEmbeddingService.cosineSimilarity(v1, v3), closeTo(0.0, 0.0001));
    });

    test('Generates normalized 192-dimensional vector', () {
      final embedding = FaceEmbeddingService.extractEmbedding(
        boundingBoxRatio: 1.2,
        eyeDistanceRatio: 0.8,
        noseToMouthRatio: 0.9,
        rawFeaturesSeed: 'user_face_sample_1',
      );

      expect(embedding.length, equals(192));
      
      // Check L2 norm equals 1.0
      double sumSquares = 0.0;
      for (var val in embedding) {
        sumSquares += val * val;
      }
      expect(sumSquares, closeTo(1.0, 0.01));
    });

    test('Correctly identifies matching face within threshold', () {
      final face1Scan1 = FaceEmbeddingService.extractEmbedding(
        boundingBoxRatio: 1.30,
        eyeDistanceRatio: 0.45,
        noseToMouthRatio: 0.25,
      );

      // Same person slightly shifted in next scan
      final face1Scan2 = FaceEmbeddingService.extractEmbedding(
        boundingBoxRatio: 1.32,
        eyeDistanceRatio: 0.44,
        noseToMouthRatio: 0.26,
      );

      // Different person with completely different geometry
      final face2 = FaceEmbeddingService.extractEmbedding(
        boundingBoxRatio: 0.95,
        eyeDistanceRatio: 0.65,
        noseToMouthRatio: 0.42,
      );

      final activeEmbeddings = {
        'person_user_1': face1Scan1,
      };

      // Query with same person in scan 2
      final match1 = FaceEmbeddingService.findMatchingCooldownFace(
        queryEmbedding: face1Scan2,
        activeEmbeddings: activeEmbeddings,
      );
      expect(match1, equals('person_user_1'));

      // Query with different person
      final match2 = FaceEmbeddingService.findMatchingCooldownFace(
        queryEmbedding: face2,
        activeEmbeddings: activeEmbeddings,
      );
      expect(match2, isNull);
    });
  });

  group('VoicePromptService Tests', () {
    test('Plays audio prompt and updates lastPrompt', () async {
      final service = VoicePromptService();
      await service.playPrompt(VoicePromptType.welcome);
      expect(service.lastPrompt, equals(VoicePromptType.welcome));

      await service.playPrompt(VoicePromptType.dispensing);
      expect(service.lastPrompt, equals(VoicePromptType.dispensing));
    });
  });
}
