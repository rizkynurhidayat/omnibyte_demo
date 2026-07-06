import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnibyte_demo/features/chat/presentation/pages/chat_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: ChatPage(),
    );
  }

  testWidgets('renders ChatPage with initial message and input elements', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Verify app bar title
    expect(find.text('Customer Support'), findsOneWidget);

    // Verify initial message from bot
    expect(find.text('Halo! Ada yang bisa kami bantu terkait demo pemindaian wajah atau KTP?'), findsOneWidget);

    // Verify input elements
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('typing and sending a message adds it to chat list and triggers bot reply', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    const userText = 'Bagaimana cara memindai KTP?';

    // Type text in the TextField
    await tester.enterText(find.byType(TextField), userText);
    await tester.pump();

    // Tap the send button
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // Verify user message is added and TextField is cleared
    expect(find.text(userText), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);

    // Fast-forward 1 second for the simulated auto-reply
    await tester.pump(const Duration(seconds: 1));

    // Verify bot reply is displayed
    expect(
      find.text('Terima kasih atas pesan Anda. Tim support kami akan segera merespon pertanyaan mengenai: "$userText".'),
      findsOneWidget,
    );
  });
}
