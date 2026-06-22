import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/verification_entity.dart';
import '../repositories/scanner_repository.dart';

class SubmitSelfieWithKtpUseCase {
  final ScannerRepository repository;

  SubmitSelfieWithKtpUseCase(this.repository);

  Future<Either<Failure, VerificationEntity>> call(String imagePath) async {
    return await repository.submitSelfieWithKtp(imagePath);
  }
}
