import 'package:flutter/material.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Month-and-year picker (Flutter has no built-in one): a year stepper
/// over a 4×3 grid of months. Returns the first day of the picked month,
/// or null if cancelled.
Future<DateTime?> showMonthPicker(BuildContext context, {DateTime? initial}) {
  final start = initial ?? DateTime.now();
  var year = start.year;
  return showDialog<DateTime>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous year',
              onPressed: () => setState(() => year -= 1),
            ),
            Expanded(child: Text('$year', textAlign: TextAlign.center)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next year',
              onPressed: () => setState(() => year += 1),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              for (var m = 1; m <= 12; m++)
                year == start.year && m == start.month && initial != null
                    ? FilledButton(
                        onPressed: () => Navigator.of(context).pop(DateTime(year, m)),
                        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(_monthNames[m - 1]),
                      )
                    : OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(DateTime(year, m)),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(_monthNames[m - 1]),
                      ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
      ),
    ),
  );
}

String shortMonthName(int month) => _monthNames[month - 1];
