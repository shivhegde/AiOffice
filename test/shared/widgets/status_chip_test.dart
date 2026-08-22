import 'package:aioffice/app/theme/app_theme.dart';
import 'package:aioffice/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

  testWidgets('renders label text', (tester) async {
    await tester.pumpWidget(wrap(const StatusChip(label: 'Pending', variant: StatusChipVariant.warn)));
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('hides the dot when showDot is false', (tester) async {
    await tester.pumpWidget(
      wrap(const StatusChip(label: 'Active', variant: StatusChipVariant.good, showDot: false)),
    );
    expect(find.byType(Container), findsWidgets);
    expect(find.text('Active'), findsOneWidget);
  });
}
