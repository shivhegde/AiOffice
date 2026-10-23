import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Prototype's `.table-wrap table` — horizontally-scrollable data table
/// with muted uppercase headers, matching the prototype's density.
///
/// On Windows a mouse wheel only scrolls vertically, and a bottom scrollbar
/// sits below the fold on long tables, so the horizontal overflow gets an
/// always-visible scrollbar pinned above the header, plus mouse
/// click-and-drag panning (Shift+wheel also scrolls sideways).
class AppDataTable extends StatefulWidget {
  const AppDataTable({super.key, required this.columns, required this.rows});

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  State<AppDataTable> createState() => _AppDataTableState();
}

class _AppDataTableState extends State<AppDataTable> {
  final _hController = ScrollController();

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.columns;
    final rows = widget.rows;
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

    final table = DataTable(
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
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {...PointerDeviceKind.values}, scrollbars: false),
      child: Scrollbar(
        controller: _hController,
        thumbVisibility: true,
        trackVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.top,
        child: SingleChildScrollView(
          controller: _hController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: 12),
          child: table,
        ),
      ),
    );
  }
}
