import 'package:intl/intl.dart';

final NumberFormat _fullFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: 'Rs. ',
  decimalDigits: 0,
);

final NumberFormat _compactFormat = NumberFormat.compactCurrency(
  locale: 'en_IN',
  symbol: 'Rs. ',
  decimalDigits: 1,
);

/// Full Indian-grouped amount, e.g. `Rs. 1,25,000` — matches the prototype's
/// table-cell currency display.
String formatCurrencyFull(num amount) => _fullFormat.format(amount);

/// Compact lakh/crore amount, e.g. `Rs. 18.4L` / `Rs. 4.2Cr` — matches the
/// prototype's stat-tile currency display.
String formatCurrencyCompact(num amount) => _compactFormat.format(amount);
