import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/audit_log_repository.dart';
import '../domain/audit_entry.dart';

final auditLogRepositoryProvider = Provider((ref) => AuditLogRepository(ref.watch(firestoreProvider)));

final _recentAuditEntriesProvider = StreamProvider((ref) {
  return ref.watch(auditLogRepositoryProvider).watchRecent();
});

/// REQUIREMENTS.md §10 — Admin-only (guarded by both the router and
/// `RoleGate` hiding the nav entry).
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(_recentAuditEntriesProvider);
    final colors = context.appColors;

    return entriesAsync.when(
      data: (entries) => AppCard(
        title: 'Recent activity',
        trailing: Text('${entries.length} entries', style: TextStyle(fontSize: 11.5, color: colors.textMuted)),
        child: entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No audit entries yet.', style: TextStyle(color: colors.textMuted))),
              )
            : Column(
                children: [
                  for (final entry in entries) _AuditRow(entry: entry),
                ],
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Could not load audit log: $err')),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final verb = switch (entry.action) {
      AuditAction.create => 'created',
      AuditAction.update => 'updated',
      AuditAction.delete => 'deleted',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(formatDisplayDateTime(entry.timestamp), style: TextStyle(fontSize: 12, color: colors.textMuted)),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12.6),
                children: [
                  TextSpan(text: entry.actorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' $verb ${entry.targetLabel}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
