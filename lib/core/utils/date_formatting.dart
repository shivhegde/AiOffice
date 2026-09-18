import 'package:intl/intl.dart';

final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
final DateFormat _displayDateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');
final DateFormat _displayMonthFormat = DateFormat('MMM yyyy');

String formatDisplayDate(DateTime date) => _displayDateFormat.format(date);

String formatDisplayDateTime(DateTime date) => _displayDateTimeFormat.format(date);

String formatDisplayMonth(DateTime date) => _displayMonthFormat.format(date);

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
