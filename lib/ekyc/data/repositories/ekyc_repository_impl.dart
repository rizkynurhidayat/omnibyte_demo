import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/ekyc_verification_entity.dart';
import '../../domain/repositories/ekyc_repository.dart';
import '../datasources/ekyc_remote_data_source.dart';

class EkycRepositoryImpl implements EkycRepository {
  final EkycRemoteDataSource remoteDataSource;

  EkycRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, EkycVerificationEntity>> verifyEkyc({
    required File ktpFile,
    required File selfieFile,
    required File selfieFaceFile,
    required File ktpFaceFile,
    required File ocrJsonFile,
    required String nik,
    required String name,
  }) async {
    try {
      final result = await remoteDataSource.verifyEkyc(
        ktpFile: ktpFile,
        selfieFile: selfieFile,
        selfieFaceFile: selfieFaceFile,
        ktpFaceFile: ktpFaceFile,
        ocrJsonFile: ocrJsonFile,
        nik: nik,
        name: name,
      );

      return Right(result);
    } catch (e) {
      return Left(ServerFailure('Gagal melakukan verifikasi: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, EkycVerificationEntity>> checkEkycStatus(String tusUploadId) async {
    try {
      final result = await remoteDataSource.checkEkycStatus(tusUploadId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure('Gagal mengecek status verifikasi: ${e.toString()}'));
    }
  }
}
