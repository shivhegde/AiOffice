import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_restart_io.dart' if (dart.library.js_interop) 'app_restart_web.dart' as platform;

/// Wraps the whole app (above the ProviderScope) so it can be restarted in
/// place: [restart] swaps in a new key, which throws away every provider,
/// stream and screen and builds the app again from scratch — as if it had
/// just been launched. The Firebase sign-in survives, so users land back
/// where they would on a normal launch. On Web the page is reloaded
/// instead, which also picks up a newly deployed build.
class RestartScope extends StatefulWidget {
  const RestartScope({super.key, required this.child});

  final Widget child;

  static void restart(BuildContext context) {
    if (kIsWeb) return platform.reloadPage();
    context.findAncestorStateOfType<_RestartScopeState>()?._restart();
  }

  @override
  State<RestartScope> createState() => _RestartScopeState();
}

class _RestartScopeState extends State<RestartScope> {
  Key _key = UniqueKey();

  void _restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

/// Closes the app so the next launch starts fresh. On Web (where a tab
/// can't close itself) the page is reloaded instead.
void exitApp() => kIsWeb ? platform.reloadPage() : platform.exitProcess();
