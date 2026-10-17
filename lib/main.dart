import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Test data is kept out of production by the per-admin environment
  // switch (see AppEnvironment), so debug runs use the live project too;
  // the local emulator is opt-in via --dart-define=USE_FIREBASE_EMULATOR=true.
  if (useFirebaseEmulator) {
    final host = kIsWeb ? 'localhost' : (defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost');
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }

  runApp(const ProviderScope(child: App()));
}
