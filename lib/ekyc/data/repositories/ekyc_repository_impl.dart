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
    required File ktpFaceFile,
    required File selfieFile,
  }) async {
    try {
      final result = await remoteDataSource.verifyEkyc(
        ktpFile: ktpFile,
        ktpFaceFile: ktpFaceFile,
        selfieFile: selfieFile,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
