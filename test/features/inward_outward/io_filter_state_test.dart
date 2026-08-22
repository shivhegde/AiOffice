import 'package:aioffice/features/inward_outward/application/io_providers.dart';
import 'package:aioffice/features/inward_outward/domain/io_document.dart';
import 'package:aioffice/features/inward_outward/domain/io_enums.dart';
import 'package:flutter_test/flutter_test.dart';

IoDocument _doc({
  String subject = 'Work Order — Facility Mgmt',
  String department = 'BWSSB',
  IoPriority priority = IoPriority.normal,
  String docNumber = 'INW/2026/0458',
}) {
  return IoDocument(
    id: 'x',
    type: IoType.inward,
    docNumber: docNumber,
    year: 2026,
    date: DateTime(2026, 7, 31),
    docType: 'Work Order',
    department: department,
    subject: subject,
    remarks: '',
    receivedFrom: 'BWSSB, Bengaluru',
    priority: priority,
    createdBy: 'actor-1',
    createdByName: 'Actor One',
  );
}

void main() {
  group('IoFilterState.matches', () {
    test('empty filter matches everything', () {
      expect(const IoFilterState().matches(_doc()), isTrue);
    });

    test('search matches subject case-insensitively', () {
      const filter = IoFilterState(search: 'facility');
      expect(filter.matches(_doc()), isTrue);
    });

    test('search excludes non-matching subject', () {
      const filter = IoFilterState(search: 'nonexistent');
      expect(filter.matches(_doc()), isFalse);
    });

    test('search matches doc number', () {
      const filter = IoFilterState(search: 'INW/2026/0458');
      expect(filter.matches(_doc()), isTrue);
    });

    test('department filter excludes other departments', () {
      const filter = IoFilterState(department: 'PWD');
      expect(filter.matches(_doc(department: 'BWSSB')), isFalse);
      expect(filter.matches(_doc(department: 'PWD')), isTrue);
    });

    test('priority filter excludes other priorities', () {
      const filter = IoFilterState(priority: IoPriority.urgent);
      expect(filter.matches(_doc(priority: IoPriority.normal)), isFalse);
      expect(filter.matches(_doc(priority: IoPriority.urgent)), isTrue);
    });

    test('copyWith null clears a previously-set filter field', () {
      const withDept = IoFilterState(department: 'PWD');
      final cleared = withDept.copyWith(department: null);
      expect(cleared.department, isNull);
      expect(cleared.matches(_doc(department: 'BWSSB')), isTrue);
    });
  });
}
