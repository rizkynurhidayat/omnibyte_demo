import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/ekyc_verification_entity.dart';
import '../repositories/ekyc_repository.dart';

class CheckEkycStatusUseCase {
  final EkycRepository repository;

  CheckEkycStatusUseCase(this.repository);

  Future<Either<Failure, EkycVerificationEntity>> call(String tusUploadId) async {
    return await repository.checkEkycStatus(tusUploadId);
  }
}
