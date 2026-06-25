import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/submit_selfie_with_ktp_usecase.dart';
import 'scanner_state.dart';

class ScannerCubit extends Cubit<ScannerState> {
  final SubmitSelfieWithKtpUseCase submitUseCase;

  ScannerCubit({required this.submitUseCase}) : super(ScannerInitial());

  Future<void> uploadSelfieWithKtp(String imagePath) async {
    emit(ScannerLoading());

    final result = await submitUseCase(imagePath);

    result.fold(
      (failure) => emit(ScannerFailure(failure.message)),
      (verificationResult) => emit(ScannerSuccess(verificationResult)),
    );
  }
}
