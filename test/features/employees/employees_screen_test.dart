import 'package:aioffice/app/theme/app_theme.dart';
import 'package:aioffice/core/constants/roles.dart';
import 'package:aioffice/features/employees/application/employee_providers.dart';
import 'package:aioffice/features/employees/application/salary_providers.dart';
import 'package:aioffice/features/employees/domain/employee.dart';
import 'package:aioffice/features/employees/domain/employee_enums.dart';
import 'package:aioffice/features/employees/domain/salary_payment.dart';
import 'package:aioffice/features/employees/presentation/employees_screen.dart';
import 'package:aioffice/features/users/application/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _employee = Employee(
  id: 'emp-1',
  employeeId: 'EMP/2026/0001',
  year: 2026,
  fullName: 'Ravi Kumar',
  gender: Gender.male,
  dateOfBirth: DateTime(1992, 3, 14),
  mobileNumber: '9845066210',
  dateOfAppointment: DateTime(2026, 1, 5),
  joiningDate: DateTime(2026, 1, 5),
  department: 'Operations',
  designation: 'Supervisor',
  employeeType: EmployeeType.permanent,
  workStatus: WorkStatus.active,
  createdBy: 'actor-1',
  createdByName: 'Actor One',
);

final _payment = SalaryPayment(
  id: 'pay-1',
  employeeDocId: 'emp-1',
  employeeId: 'EMP/2026/0001',
  employeeName: 'Ravi Kumar',
  paymentDate: DateTime(2026, 10, 1),
  salaryMonth: '${DateTime.now().year}-01',
  amount: 18000,
  paymentMode: SalaryPaymentMode.neft,
  utrNumber: 'UTR123',
  createdBy: 'actor-1',
  createdByName: 'Actor One',
);

void main() {
  testWidgets('Salary details action opens the Salary Details tab filtered to that employee', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveRoleProvider.overrideWithValue(AppRole.admin),
          currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
          employeeListProvider.overrideWith((ref) => Stream.value([_employee])),
          salaryPaymentListProvider.overrideWith((ref) => Stream.value([_payment])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SingleChildScrollView(child: EmployeesScreen())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Employee Details'), findsOneWidget);
    expect(find.text('Salary Details'), findsOneWidget);
    expect(find.text('TOTAL EMPLOYEES'), findsOneWidget);

    await tester.tap(find.byTooltip('Salary details'));
    await tester.pumpAndSettle();

    expect(find.text('EMPLOYEES PAID THIS SALARY MONTH'), findsOneWidget);
    expect(find.text('AMOUNT PAID LAST SALARY MONTH'), findsOneWidget);
    expect(find.text('Total paid (all time)'), findsOneWidget);
    expect(find.text('1 of 12'), findsOneWidget);
    expect(find.text('Not paid'), findsNWidgets(11));
    expect(find.text('UTR123'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // "Add Salary Entry" opens the entry slideover with that employee picked.
    await tester.tap(find.widgetWithText(FilledButton, 'Add Salary Entry'));
    await tester.pumpAndSettle();
    final employeeField = tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>).first);
    expect(employeeField.controller!.text, 'EMP/2026/0001 — Ravi Kumar');
    expect(tester.takeException(), isNull);
  });
}
