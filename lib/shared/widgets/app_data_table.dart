import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Prototype's `.table-wrap table` — horizontally-scrollable data table
/// with muted uppercase headers, matching the prototype's density.
class AppDataTable extends StatelessWidget {
  const AppDataTable({super.key, required this.columns, required this.rows});

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('No matching records', style: TextStyle(color: colors.textMuted)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
        headingRowHeight: 38,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        columnSpacing: 22,
        horizontalMargin: 10,
        headingTextStyle: TextStyle(
          fontSize: 10.8,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: colors.textMuted,
        ),
        dataTextStyle: TextStyle(fontSize: 12.8, color: theme.colorScheme.onSurface),
        dividerThickness: 1,
      ),
    );
  }
}
