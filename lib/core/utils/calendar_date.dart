/// Calendar dates (e.g. birthdays) stored in Postgres `date` columns.
class CalendarDate {
  CalendarDate._();

  /// `yyyy-MM-dd` from the value's own year, month and day.
  ///
  /// Never convert to UTC first: a date picked as local midnight in UTC+8 is
  /// still the previous day in UTC.
  static String? toDb(DateTime? value) {
    if (value == null) return null;
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
