import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnibyte_demo/core/error/failures.dart';
import 'package:omnibyte_demo/ekyc/domain/entities/ekyc_verification_entity.dart';
import 'package:omnibyte_demo/ekyc/domain/usecases/verify_ekyc_usecase.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_bloc.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_event.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_state.dart';

class MockVerifyEkycUseCase extends Mock implements VerifyEkycUseCase {}

void main() {
  late EkycBloc ekycBloc;
  late MockVerifyEkycUseCase mockVerifyEkycUseCase;

  setUpAll(() {
    registerFallbackValue(File(''));
  });

  setUp(() {
    mockVerifyEkycUseCase = MockVerifyEkycUseCase();
    ekycBloc = EkycBloc(verifyEkycUseCase: mockVerifyEkycUseCase);
  });

  tearDown(() {
    ekycBloc.close();
  });

  test('initial state should be EkycInitial', () {
    expect(ekycBloc.state, equals(EkycInitial()));
  });

  test('ResetEkyc event should emit EkycStepKtpActive', () async {
    ekycBloc.add(ResetEkyc());
    await expectLater(
      ekycBloc.stream,
      emitsInOrder([EkycStepKtpActive()]),
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
          ktpPath: 'simulated_ktp.jpg',
          croppedFacePath: 'simulated_ktp_face.jpg',
          ocrJsonPath: 'simulated_ocr.json',
          nik: '3273012345678901',
          name: 'RIZKY NURHIDAYAT',
        ),
        const EkycStepSelfieKtpCompleted(
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
      status: 'success',
      message: 'Verifikasi berhasil!',
      nik: '3273012345678901',
      nama: 'RIZKY NURHIDAYAT',
      similarityScore: 92.5,
      livenessScore: 98.0,
    );

    when(() => mockVerifyEkycUseCase(
          ktpFile: any(named: 'ktpFile'),
          selfieFile: any(named: 'selfieFile'),
          selfieFaceFile: any(named: 'selfieFaceFile'),
          ktpFaceFile: any(named: 'ktpFaceFile'),
          ocrJsonFile: any(named: 'ocrJsonFile'),
          nik: any(named: 'nik'),
          name: any(named: 'name'),
        )).thenAnswer((_) async => const Right(successResult));

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
      emitsThrough(isA<EkycStepSelfieKtpCompleted>()),
    );

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
          ktpFile: any(named: 'ktpFile'),
          selfieFile: any(named: 'selfieFile'),
          selfieFaceFile: any(named: 'selfieFaceFile'),
          ktpFaceFile: any(named: 'ktpFaceFile'),
          ocrJsonFile: any(named: 'ocrJsonFile'),
          nik: any(named: 'nik'),
          name: any(named: 'name'),
        )).thenAnswer((_) async => const Left(failure));

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
      emitsThrough(isA<EkycStepSelfieKtpCompleted>()),
    );

    ekycBloc.add(SubmitVerification());

    await expectLater(
      ekycBloc.stream,
      emitsInOrder([
        const EkycSubmittingState(),
        isA<EkycFailureState>(),
      ]),
    );
  });
}
