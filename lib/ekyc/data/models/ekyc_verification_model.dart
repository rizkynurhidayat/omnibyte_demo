import '../../domain/entities/ekyc_verification_entity.dart';

class EkycVerificationModel extends EkycVerificationEntity {
  const EkycVerificationModel({
    required super.status,
    required super.message,
    super.tusUploadId,
    super.nik,
    super.nama,
    super.similarityScore,
  });

  factory EkycVerificationModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    
    // Status depends on data['status']. Typical values: 'Completed', 'Processing', 'Failed'.
    final statusString = data?['status']?.toString().toLowerCase() ?? json['status']?.toString().toLowerCase() ?? 'unknown';
    final reasoning = data?['reasoning']?.toString() ?? json['message']?.toString() ?? '';

    return EkycVerificationModel(
      status: statusString,
      message: reasoning,
      tusUploadId: json['tus_upload_id'],
      nik: data?['nik'],
      nama: data?['nama'],
      similarityScore: (data?['similarity'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'tus_upload_id': tusUploadId,
      'data': {
        'nik': nik,
        'nama': nama,
        'similarity': similarityScore,
      }
    };
  }
}
