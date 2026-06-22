import 'package:equatable/equatable.dart';

class VerificationEntity extends Equatable {
  final String status;
  final String message;
  final String? nik;
  final String? nama;
  final double? livenessScore;

  const VerificationEntity({
    required this.status,
    required this.message,
    this.nik,
    this.nama,
    this.livenessScore,
  });

  @override
  List<Object?> get props => [status, message, nik, nama, livenessScore];
}
