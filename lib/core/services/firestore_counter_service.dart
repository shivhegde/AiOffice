import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_paths.dart';

/// Generates document numbers like `INW/2026/0459` by atomically
/// incrementing a `counters/{type}_{year}` document inside a Firestore
/// transaction — no Cloud Function required (see Phase 1 plan decision #1).
class FirestoreCounterService {
  FirestoreCounterService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<int> nextSequence({required String type, required int year}) async {
    final counterId = '${type}_$year';
    final ref = _firestore.collection(FirestorePaths.counters).doc(counterId);

    return _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = (snapshot.data()?['value'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      transaction.set(ref, {'value': next}, SetOptions(merge: true));
      return next;
    });
  }

  static String formatDocNumber({
    required String prefix,
    required int year,
    required int sequence,
  }) {
    return '$prefix/$year/${sequence.toString().padLeft(4, '0')}';
  }
}
