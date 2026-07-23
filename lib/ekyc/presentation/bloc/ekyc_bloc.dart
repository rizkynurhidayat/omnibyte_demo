import 'dart:io';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/image_utils.dart';
import '../../domain/usecases/verify_ekyc_usecase.dart';
import '../../domain/usecases/check_ekyc_status_usecase.dart';
import 'ekyc_event.dart';
import 'ekyc_state.dart';
import '../../domain/entities/document_type.dart';

class EkycBloc extends Bloc<EkycEvent, EkycState> {
  final VerifyEkycUseCase verifyEkycUseCase;
  final CheckEkycStatusUseCase checkEkycStatusUseCase;

  EkycBloc({
    required this.verifyEkycUseCase,
    required this.checkEkycStatusUseCase,
  }) : super(EkycInitial()) {
    on<ResetEkyc>(_onResetEkyc);
    on<KtpCaptured>(_onKtpCaptured);
    on<StartSelfieKtpScan>(_onStartSelfieKtpScan);
    on<RestoreState>(_onRestoreState);
    on<SelfieKtpCaptured>(_onSelfieKtpCaptured);
    on<SubmitVerification>(_onSubmitVerification);
    on<RefreshVerificationStatus>(_onRefreshVerificationStatus);
    on<SetFailure>(_onSetFailure);
  }

  void _onResetEkyc(ResetEkyc event, Emitter<EkycState> emit) {
    emit(EkycStepKtpActive(event.documentType));
  }

  void _onRestoreState(RestoreState event, Emitter<EkycState> emit) {
    emit(event.state);
  }

  void _onKtpCaptured(KtpCaptured event, Emitter<EkycState> emit) {
    final currentState = state;
    final docType = (currentState is EkycStepKtpActive && currentState.documentType != DocumentType.auto)
        ? currentState.documentType
        : event.detectedDocumentType;
    emit(EkycStepKtpCompleted(
      documentType: docType,
      ktpPath: event.ktpPath,
      croppedFacePath: event.croppedFacePath,
      ocrJsonPath: event.ocrJsonPath,
      nik: event.nik,
      name: event.name,
    ));
  }

  void _onStartSelfieKtpScan(StartSelfieKtpScan event, Emitter<EkycState> emit) {
    final currentState = state;
    final docType = currentState is EkycStepKtpCompleted ? currentState.documentType : DocumentType.ktp;
    emit(EkycStepSelfieKtpActive(
      documentType: docType,
      ktpPath: event.ktpPath,
      croppedFacePath: event.croppedFacePath,
      ocrJsonPath: event.ocrJsonPath,
      nik: event.nik,
      name: event.name,
    ));
  }

  void _onSelfieKtpCaptured(SelfieKtpCaptured event, Emitter<EkycState> emit) {
    final currentState = state;
    if (currentState is EkycStepSelfieKtpActive) {
      emit(EkycStepSelfieKtpCompleted(
        documentType: currentState.documentType,
        ktpPath: currentState.ktpPath,
        croppedFacePath: currentState.croppedFacePath,
        ocrJsonPath: currentState.ocrJsonPath,
        nik: currentState.nik,
        name: currentState.name,
        selfiePath: event.selfiePath,
        croppedSelfieFacePath: event.croppedSelfieFacePath,
        croppedKtpFacePath: event.croppedKtpFacePath,
      ));
    }
  }

  Future<void> _onSubmitVerification(
    SubmitVerification event,
    Emitter<EkycState> emit,
  ) async {
    final currentState = state;
    if (currentState is! EkycStepSelfieKtpCompleted) return;

    emit(const EkycSubmittingState());

    try {
      // 1. Perform Image Compression (< 1 MB per image)
      final ktpCompressed = await ImageUtils.compressImage(currentState.ktpPath);
      final selfieCompressed = await ImageUtils.compressImage(currentState.selfiePath);
      final selfieFaceCompressed = await ImageUtils.compressImage(currentState.croppedSelfieFacePath);
      final ktpFaceCompressed = await ImageUtils.compressImage(currentState.croppedKtpFacePath);

      final ocrJsonFile = File(currentState.ocrJsonPath);

      // 2. Call verification use case
      final result = await verifyEkycUseCase(
        documentType: currentState.documentType,
        ktpFile: ktpCompressed,
        selfieFile: selfieCompressed,
        selfieFaceFile: selfieFaceCompressed,
        ktpFaceFile: ktpFaceCompressed,
        ocrJsonFile: ocrJsonFile,
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

  Future<void> _onRefreshVerificationStatus(
    RefreshVerificationStatus event,
    Emitter<EkycState> emit,
  ) async {
    final currentState = state;
    if (currentState is! EkycSuccessState) return;

    // Show loading indicator
    emit(const EkycSubmittingState());

    try {
      final result = await checkEkycStatusUseCase(event.tusUploadId);

      result.fold(
        (failure) => emit(EkycFailureState(
          errorMessage: failure.message,
          fallbackState: currentState,
        )),
        (successEntity) => emit(EkycSuccessState(successEntity)),
      );
    } catch (e) {
      emit(EkycFailureState(
        errorMessage: 'Terjadi kesalahan saat mengecek status: ${e.toString()}',
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
