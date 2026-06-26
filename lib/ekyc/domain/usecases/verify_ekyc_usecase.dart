import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/ekyc_verification_entity.dart';
import '../repositories/ekyc_repository.dart';

class VerifyEkycUseCase {
  final EkycRepository repository;

  VerifyEkycUseCase(this.repository);

  Future<Either<Failure, EkycVerificationEntity>> call({
    required File ktpFile,
    required File ktpFaceFile,
    required File selfieFile,
  }) async {
    return await repository.verifyEkyc(
      ktpFile: ktpFile,
      ktpFaceFile: ktpFaceFile,
      selfieFile: selfieFile,
    );
  }
}
