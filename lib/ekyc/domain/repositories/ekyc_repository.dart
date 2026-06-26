import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/ekyc_verification_entity.dart';

abstract class EkycRepository {
  Future<Either<Failure, EkycVerificationEntity>> verifyEkyc({
    required File ktpFile,
    required File ktpFaceFile,
    required File selfieFile,
    required String nik,
    required String name,
  });
}
