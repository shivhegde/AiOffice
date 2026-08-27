import 'package:cloud_firestore/cloud_firestore.dart';

/// §9.5.6 Follow-up — one entry in a case's follow-up log, e.g.
/// "Rahul — PF Withdrawal — Applied — 25 Jun 2026" (client/service/status
/// come from the parent [EpfCase], so an entry only needs its own date and
/// note). Embedded as a list on the case document rather than a
/// subcollection — a handful of log lines per case doesn't need one.
class EpfFollowUp {
  const EpfFollowUp({required this.date, required this.note});

  final DateTime date;
  final String note;

  factory EpfFollowUp.fromMap(Map<String, dynamic> data) {
    return EpfFollowUp(
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'date': Timestamp.fromDate(date), 'note': note};
  }
}
