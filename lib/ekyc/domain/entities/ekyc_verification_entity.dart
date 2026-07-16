import 'package:equatable/equatable.dart';

class EkycVerificationEntity extends Equatable {
  final String status;
  final String message;
  final String? tusUploadId;
  final String? nik;
  final String? nama;
  final double? similarityScore;

  const EkycVerificationEntity({
    required this.status,
    required this.message,
    this.tusUploadId,
    this.nik,
    this.nama,
    this.similarityScore,
  });

  @override
  List<Object?> get props => [
        status,
        message,
        tusUploadId,
        nik,
        nama,
        similarityScore,
      ];
}
