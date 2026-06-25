import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'features/demo_scanner/data/datasources/scanner_remote_data_source.dart';
import 'features/demo_scanner/data/repositories/scanner_repository_impl.dart';
import 'features/demo_scanner/domain/repositories/scanner_repository.dart';
import 'features/demo_scanner/domain/usecases/submit_selfie_with_ktp_usecase.dart';
import 'features/demo_scanner/presentation/cubit/scanner_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core
  sl.registerLazySingleton(() => Dio());

  // Features - Demo Scanner
  // Data sources
  sl.registerLazySingleton<ScannerRemoteDataSource>(
    () => ScannerRemoteDataSourceImpl(sl()),
  );

  // Repository
  sl.registerLazySingleton<ScannerRepository>(
    () => ScannerRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => SubmitSelfieWithKtpUseCase(sl()));

  // Cubit / Bloc
  sl.registerFactory(() => ScannerCubit(submitUseCase: sl()));
}
