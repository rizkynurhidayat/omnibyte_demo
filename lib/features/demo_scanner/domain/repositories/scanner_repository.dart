import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/verification_entity.dart';

abstract class ScannerRepository {
  Future<Either<Failure, VerificationEntity>> submitSelfieWithKtp(String imagePath);
}
