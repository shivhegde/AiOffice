import 'package:aioffice/features/departments/data/department_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DepartmentRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = DepartmentRepository(firestore: firestore);
  });

  test('ensureExists adds a new department', () async {
    await repository.ensureExists(name: 'Finance', actorUid: 'actor-1');

    final stored = await repository.watchAll().first;
    expect(stored.single.name, 'Finance');
  });

  test('ensureExists does not duplicate an existing name, case-insensitively', () async {
    await repository.ensureExists(name: 'Finance', actorUid: 'actor-1');
    await repository.ensureExists(name: 'finance', actorUid: 'actor-2');
    await repository.ensureExists(name: '  FINANCE  ', actorUid: 'actor-3');

    final stored = await repository.watchAll().first;
    expect(stored.length, 1);
    expect(stored.single.name, 'Finance');
  });

  test('ensureExists is a no-op for a blank name', () async {
    await repository.ensureExists(name: '   ', actorUid: 'actor-1');

    final stored = await repository.watchAll().first;
    expect(stored, isEmpty);
  });

  test('watchAll returns departments sorted by name', () async {
    await repository.ensureExists(name: 'Works', actorUid: 'actor-1');
    await repository.ensureExists(name: 'Finance', actorUid: 'actor-1');
    await repository.ensureExists(name: 'Health', actorUid: 'actor-1');

    final stored = await repository.watchAll().first;
    expect(stored.map((d) => d.name).toList(), ['Finance', 'Health', 'Works']);
  });
}
