import 'package:aioffice/features/inward_outward/domain/io_enums.dart';
import 'package:aioffice/features/inward_outward/domain/io_followup.dart';
import 'package:flutter_test/flutter_test.dart';

IoFollowup _f(String id, DateTime date, FollowupStatus status) => IoFollowup(
  id: id,
  documentId: 'doc1',
  docNumber: 'INW/2026/001',
  type: IoType.inward,
  followupDate: date,
  remark: 'remark $id',
  status: status,
  createdBy: 'u1',
  createdByName: 'User',
);

void main() {
  group('currentFollowup', () {
    test('returns null when there are no followups', () {
      expect(currentFollowup(const []), isNull);
    });

    test('picks the earliest active followup, ignoring closed ones', () {
      final result = currentFollowup([
        _f('a', DateTime(2026, 10, 20), FollowupStatus.active),
        _f('b', DateTime(2026, 10, 1), FollowupStatus.closed),
        _f('c', DateTime(2026, 10, 18), FollowupStatus.active),
      ]);
      expect(result?.id, 'c');
    });

    test('falls back to the latest closed followup when none are active', () {
      final result = currentFollowup([
        _f('a', DateTime(2026, 9, 1), FollowupStatus.closed),
        _f('b', DateTime(2026, 10, 5), FollowupStatus.closed),
      ]);
      expect(result?.id, 'b');
    });
  });
}
