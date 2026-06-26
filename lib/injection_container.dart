import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'features/demo_scanner/data/datasources/scanner_remote_data_source.dart';
import 'features/demo_scanner/data/repositories/scanner_repository_impl.dart';
import 'features/demo_scanner/domain/repositories/scanner_repository.dart';
import 'features/demo_scanner/domain/usecases/submit_selfie_with_ktp_usecase.dart';
import 'features/demo_scanner/presentation/cubit/scanner_cubit.dart';
import 'ekyc/data/datasources/ekyc_remote_data_source.dart';
import 'ekyc/data/repositories/ekyc_repository_impl.dart';
import 'ekyc/domain/repositories/ekyc_repository.dart';
import 'ekyc/domain/usecases/verify_ekyc_usecase.dart';
import 'ekyc/presentation/bloc/ekyc_bloc.dart';
import 'core/services/tflite_face_verifier.dart';

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

  // =========================================================================
  // E-KYC Feature Registration
  // =========================================================================
  // Core Services
  sl.registerLazySingleton(() => TfliteFaceVerifier());

  // Data Source
  sl.registerLazySingleton<EkycRemoteDataSource>(
    () => EkycRemoteDataSourceImpl(sl()),
  );

  // Repository
  sl.registerLazySingleton<EkycRepository>(
    () => EkycRepositoryImpl(sl(), sl()),
  );

  // Use Cases
  sl.registerLazySingleton(() => VerifyEkycUseCase(sl()));

  // Bloc
  sl.registerFactory(() => EkycBloc(verifyEkycUseCase: sl()));
}
