import 'package:aioffice/core/config/app_environment.dart';
import 'package:aioffice/core/providers/firebase_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Like a real feature repository: a new object per build.
class _Repo {
  _Repo(this.firestore);
  final FirebaseFirestore firestore;
}

void main() {
  late FakeFirebaseFirestore production;
  late MockFirebaseAuth auth;
  late ProviderContainer container;
  var repoBuilds = 0;

  // Stand-in for a feature repository provider: rebuilt whenever
  // firestoreProvider notifies.
  final repoProvider = Provider<_Repo>((ref) {
    repoBuilds++;
    return _Repo(ref.watch(firestoreProvider));
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() async {
    repoBuilds = 0;
    production = FakeFirebaseFirestore();
    await production.collection('users').doc('admin1').set({'role': 'admin', 'status': 'active'});
    auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'admin1', email: 'a@x.com'));
    container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        productionFirestoreProvider.overrideWithValue(production),
      ],
    );
    container.listen(repoProvider, (_, _) {});
    container.listen(activeEnvironmentProvider, (_, _) {});
    await settle();
  });

  tearDown(() => container.dispose());

  test('admin without an environment field stays on production', () {
    expect(container.read(activeEnvironmentProvider).value, AppEnvironment.production);
    expect(identical(container.read(repoProvider).firestore, production), isTrue);
  });

  test('sign-out and sign-in each hand repositories a fresh Firestore', () async {
    final buildsBefore = repoBuilds;

    await auth.signOut();
    await settle();
    final afterSignOut = repoBuilds;
    expect(afterSignOut, greaterThan(buildsBefore), reason: 'sign-out must restart data streams');

    await auth.signInWithEmailAndPassword(email: 'a@x.com', password: 'x');
    await settle();
    expect(repoBuilds, greaterThan(afterSignOut), reason: 'sign-in must restart streams that died while signed out');
    expect(identical(container.read(repoProvider).firestore, production), isTrue);
  });

  test('a stream that errored while signed out is re-subscribed after sign-in', () async {
    var subscriptions = 0;
    final listProvider = StreamProvider<int>((ref) {
      ref.watch(repoProvider);
      subscriptions++;
      return Stream.value(subscriptions);
    });
    container.listen(listProvider, (_, _) {});
    await settle();
    final before = subscriptions;

    await auth.signOut();
    await settle();
    await auth.signInWithEmailAndPassword(email: 'a@x.com', password: 'x');
    await settle();

    expect(subscriptions, greaterThanOrEqualTo(before + 2));
    expect(container.read(listProvider).value, subscriptions);
  });
}
