import 'package:equatable/equatable.dart';

class EkycVerificationEntity extends Equatable {
  final String status;
  final String message;
  final String? nik;
  final String? nama;
  final double? similarityScore;
  final double? livenessScore;

  const EkycVerificationEntity({
    required this.status,
    required this.message,
    this.nik,
    this.nama,
    this.similarityScore,
    this.livenessScore,
  });

  @override
  List<Object?> get props => [
        status,
        message,
        nik,
        nama,
        similarityScore,
        livenessScore,
      ];
}
