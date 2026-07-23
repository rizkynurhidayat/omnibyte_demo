import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnibyte_demo/ekyc/domain/entities/ekyc_verification_entity.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_bloc.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_event.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_state.dart';
import 'package:omnibyte_demo/ekyc/presentation/pages/ekyc_page.dart';
import 'package:omnibyte_demo/ekyc/domain/entities/document_type.dart';

class MockEkycBloc extends Mock implements EkycBloc {}

void main() {
  late MockEkycBloc mockEkycBloc;
  late StreamController<EkycState> stateController;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(EkycInitial());
  });

  setUp(() {
    mockEkycBloc = MockEkycBloc();
    stateController = StreamController<EkycState>.broadcast();
    when(() => mockEkycBloc.state).thenReturn(EkycInitial());
    when(() => mockEkycBloc.stream).thenAnswer((_) => stateController.stream);
    when(() => mockEkycBloc.close()).thenAnswer((_) async {});
  });

  tearDown(() {
    stateController.close();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<EkycBloc>.value(
          value: mockEkycBloc,
          child: const EkycPage(documentType: DocumentType.ktp),
        ),
      ),
    );
  }

  testWidgets('renders loading indicator when state is EkycInitial', (WidgetTester tester) async {
    when(() => mockEkycBloc.state).thenReturn(EkycInitial());

    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders KtpReview screen and dispatches events on button clicks', (WidgetTester tester) async {
    final state = const EkycStepKtpCompleted(
      documentType: DocumentType.ktp,
      ktpPath: 'simulated_ktp.jpg',
      croppedFacePath: 'simulated_ktp_face.jpg',
      ocrJsonPath: 'simulated_ocr.json',
      nik: '3273012345678901',
      name: 'RIZKY NURHIDAYAT',
    );

    when(() => mockEkycBloc.state).thenReturn(state);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Verify static content
    expect(find.text('Verifikasi Hasil Pemindaian KTP'), findsOneWidget);
    expect(find.text('Foto KTP Utuh'), findsOneWidget);
    expect(find.text('Wajah KTP'), findsOneWidget);
    expect(find.text('3273012345678901'), findsOneWidget);
    expect(find.text('RIZKY NURHIDAYAT'), findsOneWidget);

    // Scroll buttons into view to ensure hit testing passes
    await tester.ensureVisible(find.text('Foto Ulang KTP'));
    await tester.pumpAndSettle();

    // Click Foto Ulang KTP
    await tester.tap(find.text('Foto Ulang KTP'));
    await tester.pump();
    // 1 call from initState, 1 call from button press
    verify(() => mockEkycBloc.add(const ResetEkyc(DocumentType.ktp))).called(2);

    await tester.ensureVisible(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    // Click Lanjutkan
    await tester.tap(find.text('Lanjutkan'));
    await tester.pump();
    verify(() => mockEkycBloc.add(const StartSelfieKtpScan(
          ktpPath: 'simulated_ktp.jpg',
          croppedFacePath: 'simulated_ktp_face.jpg',
          ocrJsonPath: 'simulated_ocr.json',
          nik: '3273012345678901',
          name: 'RIZKY NURHIDAYAT',
        ))).called(1);
  });

  testWidgets('renders SelfieKtpReview screen and dispatches events on button clicks', (WidgetTester tester) async {
    final state = const EkycStepSelfieKtpCompleted(
      documentType: DocumentType.ktp,
      ktpPath: 'simulated_ktp.jpg',
      croppedFacePath: 'simulated_ktp_face.jpg',
      ocrJsonPath: 'simulated_ocr.json',
      nik: '3273012345678901',
      name: 'RIZKY NURHIDAYAT',
      selfiePath: 'simulated_selfie.jpg',
      croppedSelfieFacePath: 'simulated_selfie_face.jpg',
      croppedKtpFacePath: 'simulated_ktp_face.jpg',
    );

    when(() => mockEkycBloc.state).thenReturn(state);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Verify static content
    expect(find.text('Pratinjau Selfie & KTP'), findsOneWidget);
    expect(find.text('Foto Selfie + KTP'), findsOneWidget);
    expect(find.text('Wajah Selfie'), findsOneWidget);
    expect(find.text('Wajah KTP (dari Selfie)'), findsOneWidget);

    // Scroll buttons into view
    await tester.ensureVisible(find.text('Ulangi Selfie'));
    await tester.pumpAndSettle();

    // Click Ulangi Selfie
    await tester.tap(find.text('Ulangi Selfie'));
    await tester.pump();
    verify(() => mockEkycBloc.add(const StartSelfieKtpScan(
          ktpPath: 'simulated_ktp.jpg',
          croppedFacePath: 'simulated_ktp_face.jpg',
          ocrJsonPath: 'simulated_ocr.json',
          nik: '3273012345678901',
          name: 'RIZKY NURHIDAYAT',
        ))).called(1);

    await tester.ensureVisible(find.text('Verifikasi Sekarang'));
    await tester.pumpAndSettle();

    // Click Verifikasi Sekarang
    await tester.tap(find.text('Verifikasi Sekarang'));
    await tester.pump();
    verify(() => mockEkycBloc.add(SubmitVerification())).called(1);
  });

  testWidgets('renders fullscreen submitting loading overlay when state is EkycSubmittingState', (WidgetTester tester) async {
    final state = const EkycSubmittingState();

    when(() => mockEkycBloc.state).thenReturn(state);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Verify loading overlay
    expect(find.text('Verifikasi Biometrik'), findsOneWidget);
    expect(find.text('Mengunggah data & mencocokkan wajah...'), findsOneWidget);
  });

  testWidgets('renders SuccessScreen on verification success', (WidgetTester tester) async {
    final state = const EkycSuccessState(EkycVerificationEntity(
      status: 'completed',
      verificationResult: 'Auto Approved',
      message: 'Cocok 92%',
      nik: '3273012345678901',
      nama: 'RIZKY NURHIDAYAT',
      similarityScore: 92.0,
      // livenessScore: 95.0,
    ));

    when(() => mockEkycBloc.state).thenReturn(state);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.text('Verifikasi Berhasil!'), findsOneWidget);
    expect(find.text('Cocok 92%'), findsOneWidget);
    expect(find.text('Kembali ke Home'), findsOneWidget);
  });

  testWidgets('renders SuccessScreen failure status on verification failure', (WidgetTester tester) async {
    final state = const EkycSuccessState(EkycVerificationEntity(
      status: 'failed',
      message: 'Wajah tidak cocok dengan KTP',
      nik: '3273012345678901',
      nama: 'RIZKY NURHIDAYAT',
      similarityScore: 40.0,
      // livenessScore: 90.0,
    ));

    when(() => mockEkycBloc.state).thenReturn(state);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.text('Verifikasi Gagal'), findsOneWidget);
    expect(find.text('Wajah tidak cocok dengan KTP'), findsOneWidget);

    // Scroll to button
    await tester.ensureVisible(find.text('Ulangi Verifikasi'));
    await tester.pumpAndSettle();

    // Tap Ulangi Verifikasi
    await tester.tap(find.text('Ulangi Verifikasi'));
    await tester.pump();
    verify(() => mockEkycBloc.add(const ResetEkyc(DocumentType.ktp))).called(2); // 1 from initState, 1 from button press
  });

  testWidgets('shows failure dialog when state is EkycFailureState and click Coba Lagi', (WidgetTester tester) async {
    final fallback = const EkycStepKtpActive(DocumentType.ktp);
    final failureState = EkycFailureState(
      errorMessage: 'Koneksi terputus',
      fallbackState: fallback,
    );

    // Initially return the fallback state
    when(() => mockEkycBloc.state).thenReturn(fallback);

    await tester.pumpWidget(createWidgetUnderTest());

    // Switch mock return and emit the state via controller to trigger BlocConsumer listener
    when(() => mockEkycBloc.state).thenReturn(failureState);
    stateController.add(failureState);
    await tester.pump();

    // Verify dialog shows up
    expect(find.text('Terjadi Masalah'), findsOneWidget);
    expect(find.text('Koneksi terputus'), findsOneWidget);

    // Tap Coba Lagi
    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();

    verify(() => mockEkycBloc.add(RestoreState(fallback))).called(1);
  });
}
