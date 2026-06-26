import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/image_utils.dart';
import '../../domain/usecases/verify_ekyc_usecase.dart';
import 'ekyc_event.dart';
import 'ekyc_state.dart';

class EkycBloc extends Bloc<EkycEvent, EkycState> {
  final VerifyEkycUseCase verifyEkycUseCase;

  EkycBloc({required this.verifyEkycUseCase}) : super(EkycInitial()) {
    on<ResetEkyc>(_onResetEkyc);
    on<KtpCaptured>(_onKtpCaptured);
    on<StartLivenessScan>(_onStartLivenessScan);
    on<RestoreState>(_onRestoreState);
    on<LivenessCaptured>(_onLivenessCaptured);
    on<SubmitVerification>(_onSubmitVerification);
    on<SetFailure>(_onSetFailure);
  }

  void _onResetEkyc(ResetEkyc event, Emitter<EkycState> emit) {
    emit(EkycStepKtpActive());
  }

  void _onRestoreState(RestoreState event, Emitter<EkycState> emit) {
    emit(event.state);
  }

  void _onKtpCaptured(KtpCaptured event, Emitter<EkycState> emit) {
    emit(EkycStepKtpCompleted(
      ktpPath: event.ktpPath,
      croppedFacePath: event.croppedFacePath,
      nik: event.nik,
      name: event.name,
    ));
  }

  void _onStartLivenessScan(StartLivenessScan event, Emitter<EkycState> emit) {
    emit(EkycStepLivenessActive(
      ktpPath: event.ktpPath,
      croppedFacePath: event.croppedFacePath,
      nik: event.nik,
      name: event.name,
    ));
  }

  void _onLivenessCaptured(LivenessCaptured event, Emitter<EkycState> emit) {
    final currentState = state;
    if (currentState is EkycStepLivenessActive) {
      emit(EkycStepLivenessCompleted(
        ktpPath: currentState.ktpPath,
        croppedFacePath: currentState.croppedFacePath,
        nik: currentState.nik,
        name: currentState.name,
        selfiePath: event.selfiePath,
      ));
    }
  }

  Future<void> _onSubmitVerification(
    SubmitVerification event,
    Emitter<EkycState> emit,
  ) async {
    final currentState = state;
    if (currentState is! EkycStepLivenessCompleted) return;

    emit(const EkycSubmittingState());

    try {
      // 1. Perform Image Compression (< 1 MB per image)
      final ktpCompressed = await ImageUtils.compressImage(currentState.ktpPath);
      final faceCompressed = await ImageUtils.compressImage(currentState.croppedFacePath);
      final selfieCompressed = await ImageUtils.compressImage(currentState.selfiePath);

      // 2. Call verification use case
      final result = await verifyEkycUseCase(
        ktpFile: ktpCompressed,
        ktpFaceFile: faceCompressed,
        selfieFile: selfieCompressed,
        nik: currentState.nik,
        name: currentState.name,
      );

      result.fold(
        (failure) => emit(EkycFailureState(
          errorMessage: failure.message,
          fallbackState: currentState,
        )),
        (successEntity) => emit(EkycSuccessState(successEntity)),
      );
    } catch (e) {
      emit(EkycFailureState(
        errorMessage: 'Terjadi kesalahan saat memproses gambar: ${e.toString()}',
        fallbackState: currentState,
      ));
    }
  }

  void _onSetFailure(SetFailure event, Emitter<EkycState> emit) {
    emit(EkycFailureState(
      errorMessage: event.errorMessage,
      fallbackState: state,
    ));
  }
}
