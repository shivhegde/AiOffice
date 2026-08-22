import 'package:aioffice/core/utils/currency_formatting.dart';
import 'package:aioffice/core/utils/date_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('currency formatting', () {
    test('formatCurrencyFull uses Indian digit grouping', () {
      expect(formatCurrencyFull(125000), 'Rs. 1,25,000');
    });

    test('formatCurrencyCompact renders lakh suffix', () {
      expect(formatCurrencyCompact(1840000), 'Rs. 18.4L');
    });

    test('formatCurrencyCompact renders crore suffix', () {
      expect(formatCurrencyCompact(42000000), 'Rs. 4.2Cr');
    });
  });

  group('date formatting', () {
    test('formatDisplayDate renders dd MMM yyyy', () {
      expect(formatDisplayDate(DateTime(2026, 7, 31)), '31 Jul 2026');
    });

    test('isSameDay ignores time-of-day', () {
      final a = DateTime(2026, 7, 31, 9, 15);
      final b = DateTime(2026, 7, 31, 22, 50);
      final c = DateTime(2026, 8, 1, 0, 1);
      expect(isSameDay(a, b), isTrue);
      expect(isSameDay(a, c), isFalse);
    });
  });
}
