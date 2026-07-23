import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnibyte_demo/core/error/failures.dart';
import 'package:omnibyte_demo/ekyc/domain/entities/ekyc_verification_entity.dart';
import 'package:omnibyte_demo/ekyc/domain/usecases/verify_ekyc_usecase.dart';
import 'package:omnibyte_demo/ekyc/domain/usecases/check_ekyc_status_usecase.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_bloc.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_event.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_state.dart';
import 'package:omnibyte_demo/ekyc/domain/entities/document_type.dart';

class MockVerifyEkycUseCase extends Mock implements VerifyEkycUseCase {}
class MockCheckEkycStatusUseCase extends Mock implements CheckEkycStatusUseCase {}

void main() {
  late EkycBloc ekycBloc;
  late MockVerifyEkycUseCase mockVerifyEkycUseCase;
  late MockCheckEkycStatusUseCase mockCheckEkycStatusUseCase;

  setUpAll(() {
    registerFallbackValue(File(''));
    registerFallbackValue(DocumentType.ktp);
  });

  setUp(() {
    mockVerifyEkycUseCase = MockVerifyEkycUseCase();
    mockCheckEkycStatusUseCase = MockCheckEkycStatusUseCase();
    ekycBloc = EkycBloc(
      verifyEkycUseCase: mockVerifyEkycUseCase,
      checkEkycStatusUseCase: mockCheckEkycStatusUseCase,
    );
  });

  tearDown(() {
    ekycBloc.close();
  });

  test('initial state should be EkycInitial', () {
    expect(ekycBloc.state, equals(EkycInitial()));
  });

  test('ResetEkyc event should emit EkycStepKtpActive', () async {
    ekycBloc.add(const ResetEkyc(DocumentType.ktp));
    await expectLater(
      ekycBloc.stream,
      emitsInOrder([const EkycStepKtpActive(DocumentType.ktp)]),
    );
  });

  test('KtpCaptured event should emit EkycStepKtpCompleted', () async {
    ekycBloc.add(const KtpCaptured(
      ktpPath: 'simulated_ktp.jpg',
      croppedFacePath: 'simulated_ktp_face.jpg',
      ocrJsonPath: 'simulated_ocr.json',
      nik: '3273012345678901',
      name: 'RIZKY NURHIDAYAT',
    ));
    await expectLater(
      ekycBloc.stream,
      emitsInOrder([
        const EkycStepKtpCompleted(
          documentType: DocumentType.ktp,
          ktpPath: 'simulated_ktp.jpg',
          croppedFacePath: 'simulated_ktp_face.jpg',
          ocrJsonPath: 'simulated_ocr.json',
          nik: '3273012345678901',
          name: 'RIZKY NURHIDAYAT',
        ),
      ]),
    );
  });

  test('StartSelfieKtpScan event should emit EkycStepSelfieKtpActive', () async {
    ekycBloc.add(const StartSelfieKtpScan(
      ktpPath: 'simulated_ktp.jpg',
      croppedFacePath: 'simulated_ktp_face.jpg',
      ocrJsonPath: 'simulated_ocr.json',
      nik: '3273012345678901',
      name: 'RIZKY NURHIDAYAT',
    ));
    await expectLater(
      ekycBloc.stream,
      emitsInOrder([
        const EkycStepSelfieKtpActive(
          documentType: DocumentType.ktp,
          ktpPath: 'simulated_ktp.jpg',
          croppedFacePath: 'simulated_ktp_face.jpg',
          ocrJsonPath: 'simulated_ocr.json',
          nik: '3273012345678901',
          name: 'RIZKY NURHIDAYAT',
        ),
      ]),
    );
  });

  test('SelfieKtpCaptured event should emit EkycStepSelfieKtpCompleted when state is EkycStepSelfieKtpActive', () async {
    ekycBloc.add(const StartSelfieKtpScan(
      ktpPath: 'simulated_ktp.jpg',
      croppedFacePath: 'simulated_ktp_face.jpg',
      ocrJsonPath: 'simulated_ocr.json',
      nik: '3273012345678901',
      name: 'RIZKY NURHIDAYAT',
    ));
    
    ekycBloc.add(const SelfieKtpCaptured(
      selfiePath: 'simulated_selfie.jpg',
      croppedSelfieFacePath: 'simulated_selfie_face.jpg',
      croppedKtpFacePath: 'simulated_ktp_face.jpg',
    ));

    await expectLater(
      ekycBloc.stream,
      emitsInOrder([
        const EkycStepSelfieKtpActive(
          documentType: DocumentType.ktp,
          ktpPath: 'simulated_ktp.jpg',
          croppedFacePath: 'simulated_ktp_face.jpg',
          ocrJsonPath: 'simulated_ocr.json',
          nik: '3273012345678901',
          name: 'RIZKY NURHIDAYAT',
        ),
        const EkycStepSelfieKtpCompleted(
          documentType: DocumentType.ktp,
          ktpPath: 'simulated_ktp.jpg',
          croppedFacePath: 'simulated_ktp_face.jpg',
          ocrJsonPath: 'simulated_ocr.json',
          nik: '3273012345678901',
          name: 'RIZKY NURHIDAYAT',
          selfiePath: 'simulated_selfie.jpg',
          croppedSelfieFacePath: 'simulated_selfie_face.jpg',
          croppedKtpFacePath: 'simulated_ktp_face.jpg',
        ),
      ]),
    );
  });

  test('SubmitVerification event should emit [EkycSubmittingState, EkycSuccessState] on success', () async {
    const successResult = EkycVerificationEntity(
      status: 'pending',
      message: 'Verifikasi berhasil dikirim!',
      tusUploadId: 'test_tus_id_123',
      nik: '3273012345678901',
      nama: 'RIZKY NURHIDAYAT',
    );

    when(() => mockVerifyEkycUseCase(
          documentType: any(named: 'documentType'),
          ktpFile: any(named: 'ktpFile'),
          selfieFile: any(named: 'selfieFile'),
          selfieFaceFile: any(named: 'selfieFaceFile'),
          ktpFaceFile: any(named: 'ktpFaceFile'),
          ocrJsonFile: any(named: 'ocrJsonFile'),
          nik: any(named: 'nik'),
          name: any(named: 'name'),
        )).thenAnswer((_) async => const Right(successResult));

    // Force bloc into EkycStepSelfieKtpCompleted state
    ekycBloc.emit(const EkycStepSelfieKtpCompleted(
      documentType: DocumentType.ktp,
      ktpPath: 'simulated_ktp.jpg',
      croppedFacePath: 'simulated_ktp_face.jpg',
      ocrJsonPath: 'simulated_ocr.json',
      nik: '3273012345678901',
      name: 'RIZKY NURHIDAYAT',
      selfiePath: 'simulated_selfie.jpg',
      croppedSelfieFacePath: 'simulated_selfie_face.jpg',
      croppedKtpFacePath: 'simulated_ktp_face.jpg',
    ));

    ekycBloc.add(SubmitVerification());

    await expectLater(
      ekycBloc.stream,
      emitsInOrder([
        const EkycSubmittingState(),
        const EkycSuccessState(successResult),
      ]),
    );
  });

  test('SubmitVerification event should emit [EkycSubmittingState, EkycFailureState] on failure', () async {
    const failure = ServerFailure('Gagal menghubungi server verifikasi.');

    when(() => mockVerifyEkycUseCase(
          documentType: any(named: 'documentType'),
          ktpFile: any(named: 'ktpFile'),
          selfieFile: any(named: 'selfieFile'),
          selfieFaceFile: any(named: 'selfieFaceFile'),
          ktpFaceFile: any(named: 'ktpFaceFile'),
          ocrJsonFile: any(named: 'ocrJsonFile'),
          nik: any(named: 'nik'),
          name: any(named: 'name'),
        )).thenAnswer((_) async => const Left(failure));

    ekycBloc.emit(const EkycStepSelfieKtpCompleted(
      documentType: DocumentType.ktp,
      ktpPath: 'simulated_ktp.jpg',
      croppedFacePath: 'simulated_ktp_face.jpg',
      ocrJsonPath: 'simulated_ocr.json',
      nik: '3273012345678901',
      name: 'RIZKY NURHIDAYAT',
      selfiePath: 'simulated_selfie.jpg',
      croppedSelfieFacePath: 'simulated_selfie_face.jpg',
      croppedKtpFacePath: 'simulated_ktp_face.jpg',
    ));

    ekycBloc.add(SubmitVerification());

    await expectLater(
      ekycBloc.stream,
      emitsInOrder([
        const EkycSubmittingState(),
        isA<EkycFailureState>(),
      ]),
    );
  });

  test('RefreshVerificationStatus should emit [EkycSubmittingState, EkycSuccessState] on success', () async {
    const pendingResult = EkycVerificationEntity(
      status: 'pending',
      message: 'Pending',
      tusUploadId: 'test_tus_id_123',
    );
    const finalResult = EkycVerificationEntity(
      status: 'Completed',
      message: 'Success',
      nik: '123456',
      nama: 'Test Name',
      similarityScore: 99.0,
    );

    when(() => mockCheckEkycStatusUseCase('test_tus_id_123'))
        .thenAnswer((_) async => const Right(finalResult));

    // Force bloc into pending EkycSuccessState
    ekycBloc.emit(const EkycSuccessState(pendingResult));

    ekycBloc.add(const RefreshVerificationStatus('test_tus_id_123'));

    await expectLater(
      ekycBloc.stream,
      emitsInOrder([
        const EkycSubmittingState(),
        const EkycSuccessState(finalResult),
      ]),
    );
  });

  test('RefreshVerificationStatus should emit [EkycSubmittingState, EkycFailureState] on failure', () async {
    const pendingResult = EkycVerificationEntity(
      status: 'pending',
      message: 'Pending',
      tusUploadId: 'test_tus_id_123',
    );
    const failure = ServerFailure('Gagal cek status.');

    when(() => mockCheckEkycStatusUseCase('test_tus_id_123'))
        .thenAnswer((_) async => const Left(failure));

    // Force bloc into pending EkycSuccessState
    ekycBloc.emit(const EkycSuccessState(pendingResult));

    ekycBloc.add(const RefreshVerificationStatus('test_tus_id_123'));

    await expectLater(
      ekycBloc.stream,
      emitsInOrder([
        const EkycSubmittingState(),
        isA<EkycFailureState>(),
      ]),
    );
  });
}
