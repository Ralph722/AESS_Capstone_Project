import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';

import '../admin_shared/admin_test_harness.dart';

void main() {
  group('adminPageCount', () {
    test('rounds up to whole pages', () {
      const expected = {
        1: 1,
        8: 1,
        24: 1,
        25: 1,
        26: 2,
        50: 2,
        51: 3,
        100: 4,
      };
      expected.forEach((total, pages) {
        expect(adminPageCount(total, 25), pages, reason: 'total=$total');
      });
    });

    test('empty list or invalid size still reports one page', () {
      expect(adminPageCount(0, 25), 1);
      expect(adminPageCount(10, 0), 1);
    });

    test('clamp keeps the page inside the real range', () {
      expect(adminClampPage(1, 8, 25), 0);
      expect(adminClampPage(5, 60, 25), 2);
      expect(adminClampPage(-1, 60, 25), 0);
    });
  });

  testWidgets('8 rows at 25 per page: Page 1 of 1, next disabled', (
    tester,
  ) async {
    var changed = false;
    await pumpAdmin(
      tester,
      AdminPaginationBar(
        totalItems: 8,
        page: 0,
        pageSize: 25,
        onPageChanged: (_) => changed = true,
        onPageSizeChanged: (_) {},
      ),
    );
    expect(find.text('Page 1 of 1'), findsOneWidget);
    expect(find.text('Showing 1–8 of 8'), findsOneWidget);
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);
    expect(changed, isFalse);
  });
}
