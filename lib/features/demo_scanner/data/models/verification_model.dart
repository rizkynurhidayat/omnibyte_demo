import '../../domain/entities/verification_entity.dart';

class VerificationModel extends VerificationEntity {
  const VerificationModel({
    required super.status,
    required super.message,
    super.nik,
    super.nama,
    super.livenessScore,
  });

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    return VerificationModel(
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      nik: json['data']?['nik'],
      nama: json['data']?['nama'],
      livenessScore: (json['data']?['liveness_score'] as num?)?.toDouble(),
    );
  }
}
