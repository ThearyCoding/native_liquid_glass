// Opens and closes many native sheets with varied timing and checks every one
// opens quickly and returns its own result. iOS 15+.
//
//   cd example && flutter test integration_test/sheet_stress_test.dart -d <iOS simulator>

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

// ─── BOTTOM SHEET ENTRY POINT ───
@pragma('vm:entry-point')
void bottomSheetMain(List<String> args) {
  runLiquidGlassSheet(
    args,
    builders: {
      'echo': (context, arguments) => _EchoSheet(arguments: arguments),
    },
  );
}

/// Shows its value, then closes itself with it after `closeAfterMs`.
class _EchoSheet extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const _EchoSheet({required this.arguments});

  @override
  State<_EchoSheet> createState() => _EchoSheetState();
}

class _EchoSheetState extends State<_EchoSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ms = (widget.arguments['closeAfterMs'] as num).toInt();
      await Future<void>.delayed(Duration(milliseconds: ms));
      if (mounted) {
        LiquidGlassSheetScope.of(context).dismiss(widget.arguments['value']);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('Sheet ${widget.arguments['value']}'));
}

/// This file's library URI; `flutter test` wraps it in a generated root.
final String _libraryUri = RegExp(
  r'file://\S+?sheet_stress_test\.dart',
).firstMatch(StackTrace.current.toString())!.group(0)!;

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('30 sheets with varied timing all open fast and return', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const Scaffold(body: Center(child: Text('Host')));
          },
        ),
      ),
    );
    await LiquidGlassSheet.prewarm(libraryUri: _libraryUri);
    await _pumpFor(tester, const Duration(seconds: 2));

    final random = math.Random(7);
    final openTimes = <int>[];
    for (var i = 0; i < 30; i++) {
      final closeAfter = [150, 400, 1200, 3000][random.nextInt(4)];
      final gapAfter = [50, 300, 700, 1500][random.nextInt(4)];
      final started = DateTime.now();
      final handle = LiquidGlassSheet.show<int>(
        context: context,
        name: 'echo',
        arguments: {'value': i, 'closeAfterMs': closeAfter},
        libraryUri: _libraryUri,
      );
      int? result;
      var done = false;
      handle.result.then((v) {
        result = v;
        done = true;
      });
      while (!done) {
        if (DateTime.now().difference(started).inSeconds > 10) {
          fail('sheet $i did not close');
        }
        await tester.pump(const Duration(milliseconds: 20));
      }
      final total = DateTime.now().difference(started).inMilliseconds;
      // Time beyond the sheet's own open time is opening overhead.
      openTimes.add(total - closeAfter);
      expect(result, i, reason: 'sheet $i returned the wrong value');
      await _pumpFor(tester, Duration(milliseconds: gapAfter));
    }
    openTimes.sort();
    debugPrint(
      'STRESS overhead ms: median=${openTimes[15]} '
      'p90=${openTimes[27]} max=${openTimes.last}',
    );
  });
}
