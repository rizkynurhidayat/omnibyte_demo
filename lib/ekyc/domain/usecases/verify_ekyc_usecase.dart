import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/ekyc_verification_entity.dart';
import '../repositories/ekyc_repository.dart';
import '../entities/document_type.dart';

class VerifyEkycUseCase {
  final EkycRepository repository;

  VerifyEkycUseCase(this.repository);

  Future<Either<Failure, EkycVerificationEntity>> call({
    required DocumentType documentType,
    required File ktpFile,
    required File selfieFile,
    required File selfieFaceFile,
    required File ktpFaceFile,
    required File ocrJsonFile,
    required String nik,
    required String name,
  }) async {
    return await repository.verifyEkyc(
      documentType: documentType,
      ktpFile: ktpFile,
      selfieFile: selfieFile,
      selfieFaceFile: selfieFaceFile,
      ktpFaceFile: ktpFaceFile,
      ocrJsonFile: ocrJsonFile,
      nik: nik,
      name: name,
    );
  }
}
