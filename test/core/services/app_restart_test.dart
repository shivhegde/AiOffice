import 'package:aioffice/core/services/app_restart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _counter = StateProvider<int>((ref) => 0);

void main() {
  testWidgets('RestartScope.restart throws away all provider state', (tester) async {
    await tester.pumpWidget(
      RestartScope(
        child: ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  Text('count ${ref.watch(_counter)}'),
                  TextButton(onPressed: () => ref.read(_counter.notifier).state++, child: const Text('inc')),
                  TextButton(onPressed: () => RestartScope.restart(context), child: const Text('restart')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('inc'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    await tester.tap(find.text('restart'));
    await tester.pump();
    expect(find.text('count 0'), findsOneWidget);
  });
}
