import 'package:aioffice/features/audit/data/audit_log_repository.dart';
import 'package:aioffice/features/audit/domain/audit_entry.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _logLogin(AuditLogRepository repo) => repo.log(
  actorUid: 'u1',
  actorName: 'User One',
  action: AuditAction.login,
  module: 'auth',
  targetId: 'u1',
  targetLabel: '',
);

void main() {
  test('stamps every entry with the app version', () async {
    final firestore = FakeFirebaseFirestore();
    var lookups = 0;
    final repo = AuditLogRepository(
      firestore,
      appVersion: () async {
        lookups++;
        return '1.0.1';
      },
    );

    await _logLogin(repo);
    await _logLogin(repo);

    final entries = await repo.watchRecent().first;
    expect(entries.map((e) => e.appVersion), ['1.0.1', '1.0.1']);
    expect(entries.first.action, AuditAction.login);
    expect(lookups, 1);
  });

  test('a failed version lookup still writes the entry, unstamped', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = AuditLogRepository(firestore, appVersion: () async => throw Exception('no platform'));

    await _logLogin(repo);

    final entry = (await repo.watchRecent().first).single;
    expect(entry.appVersion, '');
    expect((await firestore.collection('audit_log').get()).docs.single.data().containsKey('appVersion'), isFalse);
  });
}
