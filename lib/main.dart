import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

/// Local dev defaults to the Firebase Local Emulator Suite (Phase 1 plan
/// decision #7) so day-to-day iteration doesn't leave test cruft in the
/// real `officeai-registry` project. Override with
/// `--dart-define=USE_FIREBASE_EMULATOR=false` to point at the live
/// project instead.
const bool _useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useFirebaseEmulator) {
    final host = kIsWeb ? 'localhost' : (defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost');
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }

  runApp(const ProviderScope(child: App()));
}
