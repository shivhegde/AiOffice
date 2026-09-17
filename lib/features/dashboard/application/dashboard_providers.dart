import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../inward_outward/application/io_providers.dart';
import '../../inward_outward/domain/io_document.dart';
import '../../inward_outward/domain/io_enums.dart';
import '../../tender_emd/application/tender_providers.dart';
import '../../tender_emd/domain/tender.dart';
import '../../tender_emd/domain/tender_enums.dart';
import '../../vehicle_insurance/application/vehicle_policy_providers.dart';
import '../../vehicle_insurance/domain/vehicle_policy.dart';
import '../../work_orders/application/work_order_providers.dart';
import '../../work_orders/domain/work_order.dart';

class DashboardStats {
  const DashboardStats({
    required this.totalInward,
    required this.totalOutward,
    required this.todayInward,
    required this.todayOutward,
    required this.emdPendingRefundAmount,
    required this.emdPendingRefundCount,
    required this.fdMaturingSoonCount,
    required this.fdMaturingSoonAmount,
  });

  final int totalInward;
  final int totalOutward;
  final int todayInward;
  final int todayOutward;

  /// §7.4-adjacent — restored to the home dashboard now that Tender-EMD is
  /// real data (Phase 1 originally omitted this tile rather than fake it).
  final double emdPendingRefundAmount;
  final int emdPendingRefundCount;

  /// §8.4-adjacent — restored alongside the above, same reasoning.
  final int fdMaturingSoonCount;
  final double fdMaturingSoonAmount;
}

/// Per-task-group document counts backing the home Dashboard's "Activity
/// by Task Group" chart — see [ActivityByTaskGroupChart].
class TaskGroupActivity {
  const TaskGroupActivity({required this.label, required this.count});

  final String label;
  final int count;
}

/// How urgently a [NeedsAttentionItem] should read in the UI — kept
/// UI-framework-agnostic here (no `StatusChipVariant` import) and mapped
/// to a chip color in the presentation layer.
enum AttentionSeverity { warning, critical }

class NeedsAttentionItem {
  const NeedsAttentionItem({
    required this.severity,
    required this.badgeLabel,
    required this.reference,
    required this.description,
    required this.date,
  });

  final AttentionSeverity severity;
  final String badgeLabel;
  final String reference;
  final String description;
  final DateTime date;
}

Iterable<AsyncValue<T>> _allLoaded<T>(List<AsyncValue<T>> values) => values;

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final inward = ref.watch(inwardListProvider);
  final outward = ref.watch(outwardListProvider);
  final tenders = ref.watch(tenderListProvider);
  final workOrders = ref.watch(workOrderListProvider);

  for (final v in _allLoaded([inward, outward, tenders, workOrders])) {
    if (v.isLoading) return const AsyncValue.loading();
  }
  for (final v in _allLoaded([inward, outward, tenders, workOrders])) {
    if (v.hasError) return AsyncValue.error(v.error!, v.stackTrace!);
  }

  final inwardDocs = inward.value ?? const <IoDocument>[];
  final outwardDocs = outward.value ?? const <IoDocument>[];
  final tenderDocs = tenders.value ?? const <Tender>[];
  final workOrderDocs = workOrders.value ?? const <WorkOrder>[];
  final now = DateTime.now();

  final pendingTenders = tenderDocs.where((t) => t.refundStatus == RefundStatus.pending).toList();
  final maturingFds = workOrderDocs.where((wo) => wo.isFdMaturingSoon).toList();

  return AsyncValue.data(
    DashboardStats(
      totalInward: inwardDocs.length,
      totalOutward: outwardDocs.length,
      todayInward: inwardDocs.where((d) => isSameDay(d.date, now)).length,
      todayOutward: outwardDocs.where((d) => isSameDay(d.date, now)).length,
      emdPendingRefundAmount: pendingTenders.fold<double>(0, (sum, t) => sum + t.emdAmount),
      emdPendingRefundCount: pendingTenders.length,
      fdMaturingSoonCount: maturingFds.length,
      fdMaturingSoonAmount: maturingFds.fold<double>(0, (sum, wo) => sum + (wo.fdAmount ?? 0)),
    ),
  );
});

final activityByTaskGroupProvider = Provider<AsyncValue<List<TaskGroupActivity>>>((ref) {
  final inward = ref.watch(inwardListProvider);
  final outward = ref.watch(outwardListProvider);
  final tenders = ref.watch(tenderListProvider);
  final workOrders = ref.watch(workOrderListProvider);

  for (final v in _allLoaded([inward, outward, tenders, workOrders])) {
    if (v.isLoading) return const AsyncValue.loading();
  }
  for (final v in _allLoaded([inward, outward, tenders, workOrders])) {
    if (v.hasError) return AsyncValue.error(v.error!, v.stackTrace!);
  }

  final generalCorrespondence = (inward.value?.length ?? 0) + (outward.value?.length ?? 0);
  final fdCount = (workOrders.value ?? const <WorkOrder>[]).where((wo) => wo.hasFd).length;

  return AsyncValue.data([
    TaskGroupActivity(label: 'Tender-EMD', count: tenders.value?.length ?? 0),
    TaskGroupActivity(label: 'Work Orders', count: workOrders.value?.length ?? 0),
    TaskGroupActivity(label: 'Fixed Deposit', count: fdCount),
    TaskGroupActivity(label: 'General Corr.', count: generalCorrespondence),
  ]);
});

/// Merges urgent inward items, EMD refund/validity alerts, and Work
/// Order/FD alerts into one feed, newest-first, capped at 8 — extends
/// Phase 1's inward-only version now that Tender-EMD/Work Orders exist.
final needsAttentionProvider = Provider<AsyncValue<List<NeedsAttentionItem>>>((ref) {
  final inward = ref.watch(inwardListProvider);
  final tenders = ref.watch(tenderListProvider);
  final workOrders = ref.watch(workOrderListProvider);
  final vehiclePolicies = ref.watch(vehiclePolicyListProvider);

  for (final v in _allLoaded([inward, tenders, workOrders, vehiclePolicies])) {
    if (v.isLoading) return const AsyncValue.loading();
  }
  for (final v in _allLoaded([inward, tenders, workOrders, vehiclePolicies])) {
    if (v.hasError) return AsyncValue.error(v.error!, v.stackTrace!);
  }

  final items = <NeedsAttentionItem>[];
  final cutoff = DateTime.now().subtract(const Duration(days: 14));

  for (final d in inward.value ?? const <IoDocument>[]) {
    if (d.priority == IoPriority.urgent && d.date.isAfter(cutoff)) {
      items.add(
        NeedsAttentionItem(
          severity: AttentionSeverity.critical,
          badgeLabel: 'Urgent',
          reference: d.docNumber,
          description: '${d.subject} · ${d.department}',
          date: d.date,
        ),
      );
    }
  }

  for (final t in tenders.value ?? const <Tender>[]) {
    if (t.isRefundOverdue) {
      items.add(
        NeedsAttentionItem(
          severity: AttentionSeverity.critical,
          badgeLabel: 'Overdue ${t.refundOverdueDays}d',
          reference: t.tenderNumber,
          description: 'EMD refund — ${t.tenderName} · ${t.departmentName}',
          date: t.submissionDate,
        ),
      );
    }
    if (t.isEmdValidityExpiringSoon) {
      items.add(
        NeedsAttentionItem(
          severity: AttentionSeverity.warning,
          badgeLabel: 'EMD expiring',
          reference: t.tenderNumber,
          description: 'EMD validity — ${t.tenderName}',
          date: t.emdValidUntil!,
        ),
      );
    }
  }

  for (final wo in workOrders.value ?? const <WorkOrder>[]) {
    if (wo.isExpiringSoon) {
      items.add(
        NeedsAttentionItem(
          severity: AttentionSeverity.warning,
          badgeLabel: 'WO expiring',
          reference: wo.workOrderNumber,
          description: 'Work order — ${wo.departmentName}',
          date: wo.endDate!,
        ),
      );
    }
    if (wo.isFdExpired || wo.isFdReleasePending) {
      items.add(
        NeedsAttentionItem(
          severity: AttentionSeverity.critical,
          badgeLabel: wo.isFdExpired ? 'FD expired' : 'FD release due',
          reference: wo.fdNumber ?? wo.workOrderNumber,
          description: 'Fixed deposit — ${wo.workOrderNumber}',
          date: wo.fdMaturityDate ?? wo.workOrderDate,
        ),
      );
    } else if (wo.isFdMaturingSoon) {
      items.add(
        NeedsAttentionItem(
          severity: AttentionSeverity.warning,
          badgeLabel: 'FD maturing',
          reference: wo.fdNumber ?? wo.workOrderNumber,
          description: 'Fixed deposit — ${wo.workOrderNumber}',
          date: wo.fdMaturityDate!,
        ),
      );
    }
  }

  for (final p in vehiclePolicies.value ?? const <VehiclePolicy>[]) {
    if (p.isExpiringWithin(7)) {
      final daysLeft = p.daysToExpiry;
      items.add(
        NeedsAttentionItem(
          severity: AttentionSeverity.warning,
          badgeLabel: 'Insurance expiring',
          reference: p.policyNumber.isNotEmpty ? p.policyNumber : p.vehicleNumber,
          description:
              'Vehicle insurance — ${p.vehicleNumber} (${p.insuranceCompany}) expires in '
              '${daysLeft <= 0 ? 'today' : '${daysLeft}d'}',
          date: p.expiryDate,
        ),
      );
    }
  }

  items.sort((a, b) {
    if (a.severity != b.severity) {
      return a.severity == AttentionSeverity.critical ? -1 : 1;
    }
    return a.date.compareTo(b.date);
  });

  return AsyncValue.data(items.take(8).toList());
});

/// Latest creates across Inward/Outward, newest first.
final recentActivityProvider = Provider<AsyncValue<List<IoDocument>>>((ref) {
  final inward = ref.watch(inwardListProvider);
  final outward = ref.watch(outwardListProvider);

  if (inward.isLoading || outward.isLoading) return const AsyncValue.loading();
  if (inward.hasError) return AsyncValue.error(inward.error!, inward.stackTrace!);
  if (outward.hasError) return AsyncValue.error(outward.error!, outward.stackTrace!);

  final combined = [...?inward.value, ...?outward.value]
    ..sort((a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date));
  return AsyncValue.data(combined.take(8).toList());
});
