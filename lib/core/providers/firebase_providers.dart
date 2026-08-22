import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raw Firebase SDK instance providers. Emulator wiring (if
/// `USE_FIREBASE_EMULATOR` is set) happens once in `main.dart` before
/// `runApp`, so these singletons already point at the right backend by the
/// time any provider below is first read.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
