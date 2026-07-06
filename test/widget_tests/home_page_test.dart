import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnibyte_demo/features/home/presentation/pages/home_page.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_bloc.dart';
import 'package:omnibyte_demo/ekyc/presentation/bloc/ekyc_state.dart';
import 'package:omnibyte_demo/ekyc/presentation/pages/ekyc_page.dart';
import 'package:omnibyte_demo/features/chat/presentation/pages/chat_page.dart';

class MockEkycBloc extends Mock implements EkycBloc {}

void main() {
  final sl = GetIt.instance;
  late MockEkycBloc mockEkycBloc;

  setUpAll(() {
    // Disable Google Fonts runtime fetching to run tests offline
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    mockEkycBloc = MockEkycBloc();
    when(() => mockEkycBloc.state).thenReturn(EkycInitial());
    when(() => mockEkycBloc.stream).thenAnswer((_) => Stream.value(EkycInitial()));
    when(() => mockEkycBloc.close()).thenAnswer((_) async {});

    // Register MockEkycBloc in GetIt
    sl.registerFactory<EkycBloc>(() => mockEkycBloc);
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: HomePage(),
    );
  }

  testWidgets('renders HomePage with title, subtitle, and menu cards', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Verify Welcome header
    expect(find.text('Halo, User!'), findsOneWidget);
    expect(find.text('Selamat datang di OmniByte Demo'), findsOneWidget);

    // Verify Info banner
    expect(find.text('Demo Biometrik & Identitas'), findsOneWidget);
    expect(find.text('Pindai wajah dan kartu identitas dengan teknologi OCR dan Deteksi Keaktifan (Liveness)'), findsOneWidget);

    // Verify Menu cards
    expect(find.text('Scanner Demo'), findsOneWidget);
    expect(find.text('Customer Service Chat'), findsOneWidget);
  });

  testWidgets('tapping Scanner Demo navigates to EkycPage', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Tap Scanner Demo card
    await tester.tap(find.text('Scanner Demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we navigated to EkycPage
    expect(find.byType(EkycPage), findsOneWidget);
    expect(find.text('Pendaftaran e-KYC'), findsOneWidget);
  });

  testWidgets('tapping Customer Service Chat navigates to ChatPage', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Tap Customer Service Chat card
    await tester.tap(find.text('Customer Service Chat'));
    await tester.pumpAndSettle();

    // Verify we navigated to ChatPage
    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.text('Customer Support'), findsOneWidget);
  });
}
