import 'dart:typed_data';

class FaceProfile {
  final int? id;
  final String faceHash;
  final List<double>? embedding192d;
  final String? note;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const FaceProfile({
    this.id,
    required this.faceHash,
    this.embedding192d,
    this.note,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  static Uint8List? embeddingToBlob(List<double>? embedding) {
    if (embedding == null || embedding.isEmpty) return null;
    final floatList = Float32List.fromList(embedding);
    return floatList.buffer.asUint8List();
  }

  static List<double>? blobToEmbedding(Uint8List? blob) {
    if (blob == null || blob.isEmpty) return null;
    final float32List = Float32List.view(
      blob.buffer,
      blob.offsetInBytes,
      blob.lengthInBytes ~/ 4,
    );
    return float32List.toList();
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'face_hash': faceHash,
      'embedding_blob': embeddingToBlob(embedding192d),
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
    };
  }

  factory FaceProfile.fromMap(Map<String, dynamic> map) {
    final blob = map['embedding_blob'] as Uint8List?;
    return FaceProfile(
      id: map['id'] as int?,
      faceHash: map['face_hash'] as String,
      embedding192d: blobToEmbedding(blob),
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
          : null,
    );
  }
}
