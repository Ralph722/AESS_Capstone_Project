import 'package:alumni_system/shared/widgets/safe_link_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _links(WidgetTester tester, String text) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SafeLinkText(text))),
  );
  final rich = tester.widget<RichText>(
    find.descendant(
      of: find.byType(SafeLinkText),
      matching: find.byType(RichText),
    ),
  );
  final links = <String>[];
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.recognizer != null) links.add(span.text!);
    return true;
  });
  return links;
}

void main() {
  testWidgets('detects https and www links without trailing punctuation', (
    tester,
  ) async {
    final links = await _links(
      tester,
      'Register at https://forms.gle/abc123, or visit www.ustp.edu.ph.',
    );
    expect(links, ['https://forms.gle/abc123', 'www.ustp.edu.ph']);
  });

  testWidgets('a www inside an https link is one link', (tester) async {
    final links = await _links(tester, 'See https://www.ustp.edu.ph/events');
    expect(links, ['https://www.ustp.edu.ph/events']);
  });

  testWidgets('plain text has no links', (tester) async {
    final links = await _links(tester, 'Bring an ID, e.g. school ID. www is not a link');
    expect(links, isEmpty);
  });
}
