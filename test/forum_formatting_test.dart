import 'package:alumni_system/features/forum/widgets/forum_format_toolbar.dart';
import 'package:alumni_system/features/forum/widgets/forum_formatted_text.dart';
import 'package:alumni_system/features/forum/widgets/forum_rich_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForumFormattedText.plain', () {
    test('strips inline markup and quote markers', () {
      expect(
        ForumFormattedText.plain(
          '**Bold** and *italic* and ***both***\n'
          '> quoted\n'
          '- item\n'
          'see [form](https://ustp.edu.ph)',
        ),
        'Bold and italic and both\nquoted\n• item\nsee form',
      );
    });

    test('leaves plain text and arithmetic alone', () {
      expect(ForumFormattedText.plain('2 * 3 * 4 = 24'), '2 * 3 * 4 = 24');
    });
  });

  group('ForumRichTextController', () {
    late ForumRichTextController c;
    setUp(() => c = ForumRichTextController());
    tearDown(() => c.dispose());

    void type(String s) {
      final sel = c.selection.isValid
          ? c.selection
          : TextSelection.collapsed(offset: c.text.length);
      c.value = TextEditingValue(
        text: c.text.replaceRange(sel.start, sel.end, s),
        selection: TextSelection.collapsed(offset: sel.start + s.length),
      );
    }

    test('bold on a selection styles it without adding asterisks', () {
      type('hello world');
      c.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
      c.toggle(ForumInline.bold);
      expect(c.text, 'hello world');
      expect(c.markdown, 'hello **world**');
      c.toggle(ForumInline.bold);
      expect(c.markdown, 'hello world');
    });

    test('bold with nothing selected applies to the next typed text', () {
      type('Hi ');
      c.toggle(ForumInline.bold);
      expect(c.isActive(ForumInline.bold), isTrue);
      type('there');
      c.toggle(ForumInline.bold);
      type(' you');
      expect(c.text, 'Hi there you');
      expect(c.markdown, 'Hi **there** you');
    });

    test('typing at the end of bold text continues bold', () {
      type('ab');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      c.toggle(ForumInline.bold);
      c.selection = const TextSelection.collapsed(offset: 2);
      type('c');
      expect(c.markdown, '**abc**');
    });

    test('spaces stay outside the markers', () {
      type('one two');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      c.toggle(ForumInline.italic);
      expect(c.markdown, '*one* two');
    });

    test('bold and italic together', () {
      type('wow');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      c.toggle(ForumInline.bold);
      c.toggle(ForumInline.italic);
      expect(c.markdown, '***wow***');
    });

    test('list prefixes are kept outside the markup', () {
      type('- item');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
      c.toggle(ForumInline.bold);
      expect(c.markdown, '- **item**');
    });

    test('links save as markup and round-trip', () {
      type('see ');
      c.insertLink(start: 4, end: 4, label: 'form', url: 'https://ustp.edu.ph');
      type(' now');
      expect(c.text, 'see form now');
      expect(c.markdown, 'see [form](https://ustp.edu.ph) now');
    });

    test('loadMarkdown shows plain text and keeps the styles', () {
      const saved = '**Hello** there\n- *one*\n> [form](https://x.org)';
      c.loadMarkdown(saved);
      expect(c.text, 'Hello there\n- one\n> form');
      expect(c.markdown, saved);
    });

    test('deleting part of bold text keeps the rest bold', () {
      c.loadMarkdown('**Hello** world');
      c.value = const TextEditingValue(
        text: 'Hell world',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(c.markdown, '**Hell** world');
    });
  });

  group('ForumFormatToolbar', () {
    late ForumRichTextController controller;

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ForumFormatToolbar(controller: controller),
                TextField(controller: controller, maxLines: 5),
              ],
            ),
          ),
        ),
      );
    }

    setUp(() => controller = ForumRichTextController());
    tearDown(() => controller.dispose());

    testWidgets('bold button styles the selection, no asterisks', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      );
      await pump(tester);

      await tester.tap(find.byTooltip('Bold'));
      expect(controller.text, 'hello world');
      expect(controller.markdown, 'hello **world**');
    });

    testWidgets('numbered list numbers each selected line and toggles off', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'intro\napples\npears',
        selection: TextSelection(baseOffset: 7, extentOffset: 17),
      );
      await pump(tester);

      await tester.tap(find.byTooltip('Numbered list'));
      expect(controller.text, 'intro\n1. apples\n2. pears');

      await tester.tap(find.byTooltip('Numbered list'));
      expect(controller.text, 'intro\napples\npears');
    });

    testWidgets('list toggling keeps bold inside the lines', (tester) async {
      controller.loadMarkdown('**a** x\n**b** y');
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 7,
      );
      await pump(tester);

      await tester.tap(find.byTooltip('Bulleted list'));
      expect(controller.markdown, '- **a** x\n- **b** y');
    });
  });

  testWidgets('renders bold, bullets and quotes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ForumFormattedText('**Hello**\n- one\n> said')),
      ),
    );

    final bold = find.byWidgetPredicate((w) {
      if (w is! RichText) return false;
      var found = false;
      w.text.visitChildren((span) {
        if (span is TextSpan &&
            span.text == 'Hello' &&
            span.style?.fontWeight == FontWeight.w700) {
          found = true;
        }
        return !found;
      });
      return found;
    });
    expect(bold, findsOneWidget);
    expect(find.text('•'), findsOneWidget);
    expect(find.text('**Hello**'), findsNothing);
  });
}
