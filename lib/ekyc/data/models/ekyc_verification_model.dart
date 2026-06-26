import '../../domain/entities/ekyc_verification_entity.dart';

class EkycVerificationModel extends EkycVerificationEntity {
  const EkycVerificationModel({
    required super.status,
    required super.message,
    super.nik,
    super.nama,
    super.similarityScore,
    super.livenessScore,
  });

  factory EkycVerificationModel.fromJson(Map<String, dynamic> json) {
    return EkycVerificationModel(
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      nik: json['data']?['nik'],
      nama: json['data']?['nama'],
      similarityScore: (json['data']?['similarity_score'] as num?)?.toDouble(),
      livenessScore: (json['data']?['liveness_score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': {
        'nik': nik,
        'nama': nama,
        'similarity_score': similarityScore,
        'liveness_score': livenessScore,
      }
    };
  }
}
