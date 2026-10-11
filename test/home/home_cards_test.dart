import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/home/widgets/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ForumTopic _topic({
  bool pinned = false,
  bool solved = false,
  bool announcement = false,
  int replies = 3,
  List<String> tags = const [],
}) {
  final now = DateTime.now();
  return ForumTopic(
    id: 't1',
    title: 'Board exam reviewers',
    body: 'Body',
    authorUid: 'u1',
    authorName: 'Ana',
    createdAt: now,
    updatedAt: now,
    replyCount: replies,
    isPinned: pinned,
    isSolved: solved,
    isAnnouncement: announcement,
    tags: [
      for (final (i, t) in tags.indexed)
        ForumTag(id: '$i', slug: t.toLowerCase(), label: t),
    ],
  );
}

Future<void> _pump(WidgetTester tester, ForumTopic topic) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomeCommunityCard(topic: topic, onTap: () {}),
      ),
    ),
  );
}

void main() {
  group('homeTracerSubtitle', () {
    test('not started without a deadline', () {
      expect(
        homeTracerSubtitle(started: false),
        'Not started · about 10–15 min',
      );
    });

    test('in progress without a deadline', () {
      expect(
        homeTracerSubtitle(started: true),
        'In progress · pick up where you left off',
      );
    });

    test('due date comes first when set', () {
      expect(
        homeTracerSubtitle(started: false, dueLabel: 'Due Oct 20'),
        'Due Oct 20 · Not started',
      );
      expect(
        homeTracerSubtitle(started: true, dueLabel: 'Due tomorrow'),
        'Due tomorrow · In progress',
      );
    });

    test('never shows a percentage', () {
      for (final started in [true, false]) {
        expect(homeTracerSubtitle(started: started), isNot(contains('%')));
      }
    });
  });

  group('HomeCommunityCard pill', () {
    testWidgets('pinned wins over everything', (tester) async {
      await _pump(
        tester,
        _topic(pinned: true, solved: true, replies: 0, tags: ['Careers']),
      );
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Solved'), findsNothing);
      expect(find.text('Careers'), findsNothing);
    });

    testWidgets('solved beats needs response and tags', (tester) async {
      await _pump(tester, _topic(solved: true, replies: 0, tags: ['Careers']));
      expect(find.text('Solved'), findsOneWidget);
      expect(find.text('Careers'), findsNothing);
    });

    testWidgets('needs response for unanswered topics', (tester) async {
      await _pump(tester, _topic(replies: 0, tags: ['Careers']));
      expect(find.text('Needs Response'), findsOneWidget);
      expect(find.text('Careers'), findsNothing);
    });

    testWidgets('falls back to the first tag', (tester) async {
      await _pump(tester, _topic(tags: ['Careers', 'Events']));
      expect(find.text('Careers'), findsOneWidget);
      expect(find.text('Events'), findsNothing);
    });

    testWidgets('no pill and never the old Discussion label', (tester) async {
      await _pump(tester, _topic());
      expect(find.text('Discussion'), findsNothing);
      expect(find.text('Pinned'), findsNothing);
      expect(find.text('Solved'), findsNothing);
      expect(find.text('Needs Response'), findsNothing);
    });
  });
}
