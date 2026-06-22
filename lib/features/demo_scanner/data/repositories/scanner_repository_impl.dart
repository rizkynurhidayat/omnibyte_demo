import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/verification_entity.dart';
import '../../domain/repositories/scanner_repository.dart';
import '../datasources/scanner_remote_data_source.dart';

class ScannerRepositoryImpl implements ScannerRepository {
  final ScannerRemoteDataSource remoteDataSource;

  ScannerRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, VerificationEntity>> submitSelfieWithKtp(String imagePath) async {
    try {
      final result = await remoteDataSource.submitSelfieWithKtp(imagePath);
      return Right(result);
    } catch (e) {
      // Menangkap error dari remote data source (contoh: dio exception, koneksi putus, dll)
      return const Left(ServerFailure('Gagal terhubung ke server verifikasi.'));
    }
  }
}
