import 'package:alumni_system/features/events/data/reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder ids are stable, distinct and fit in 32 bits', () {
    const eventId = '6de19922-d5cd-44c6-82d6-01aef69d3676';
    final a = ReminderService.reminderIdsFor(eventId);
    final b = ReminderService.reminderIdsFor(eventId);

    expect(a, b);
    expect(a.toSet().length, 3);
    for (final id in a) {
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThan(0x7FFFFFFF));
    }
    expect(
      ReminderService.reminderIdsFor('2ae98fdd-8721-44f5-afde-0f7141ff1abf'),
      isNot(a),
    );
  });
}
