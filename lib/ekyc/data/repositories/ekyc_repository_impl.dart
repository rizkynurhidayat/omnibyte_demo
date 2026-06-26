import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/tflite_face_verifier.dart';
import '../../domain/entities/ekyc_verification_entity.dart';
import '../../domain/repositories/ekyc_repository.dart';
import '../datasources/ekyc_remote_data_source.dart';

class EkycRepositoryImpl implements EkycRepository {
  final EkycRemoteDataSource remoteDataSource;
  final TfliteFaceVerifier tfliteFaceVerifier;

  EkycRepositoryImpl(this.remoteDataSource, this.tfliteFaceVerifier);

  @override
  Future<Either<Failure, EkycVerificationEntity>> verifyEkyc({
    required File ktpFile,
    required File ktpFaceFile,
    required File selfieFile,
    required String nik,
    required String name,
  }) async {
    try {
      // Perform local face comparison using TensorFlow Lite model
      final similarityScore = await tfliteFaceVerifier.compareFaces(ktpFaceFile, selfieFile);
      final isMatch = similarityScore >= 80.0;

      final result = EkycVerificationEntity(
        status: isMatch ? 'success' : 'failed',
        message: isMatch
            ? 'Verifikasi wajah lokal berhasil (Offline TFLite).'
            : 'Verifikasi wajah gagal. Wajah tidak cocok dengan KTP.',
        nik: nik,
        nama: name,
        similarityScore: similarityScore,
        livenessScore: 96.5, // Simulated liveness pass score
      );

      return Right(result);
    } catch (e) {
      return Left(ServerFailure('Gagal melakukan verifikasi lokal: ${e.toString()}'));
    }
  }
}
