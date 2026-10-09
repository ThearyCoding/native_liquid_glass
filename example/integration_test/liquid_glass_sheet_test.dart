// End-to-end test of the native LiquidGlassSheet on an iOS 15+ simulator.
//
// `flutter test` wraps this file in a generated root library, so the sheet
// engine is pointed at this file explicitly with `libraryUri`.
//
//   cd example && flutter test integration_test/liquid_glass_sheet_test.dart -d <iOS simulator>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

// ─── BOTTOM SHEET ENTRY POINT ───
@pragma('vm:entry-point')
void bottomSheetMain(List<String> args) {
  runLiquidGlassSheet(args, builders: _sheetBuilders);
}

final Map<String, LiquidGlassSheetBuilder> _sheetBuilders = {
  // Renders, then dismisses itself with `arguments['value']` after `delayMs`.
  'autoPick': (context, arguments) => _AutoPickSheet(arguments: arguments),
  // Stays open until the host app dismisses it.
  'idle': (context, arguments) =>
      const Center(child: Text('Waiting for host to dismiss')),
};

class _AutoPickSheet extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const _AutoPickSheet({required this.arguments});

  @override
  State<_AutoPickSheet> createState() => _AutoPickSheetState();
}

class _AutoPickSheetState extends State<_AutoPickSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final delay = (widget.arguments['delayMs'] as num?)?.toInt() ?? 500;
      await Future<void>.delayed(Duration(milliseconds: delay));
      if (mounted) {
        LiquidGlassSheetScope.of(context).dismiss(widget.arguments['value']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Picking ${widget.arguments['value']}…'));
  }
}

/// This file's library URI (`file:///…/liquid_glass_sheet_test.dart`), read
/// from a stack frame since Dart has no direct API for it.
final String _libraryUri = RegExp(
  r'file://\S+?liquid_glass_sheet_test\.dart',
).firstMatch(StackTrace.current.toString())!.group(0)!;

/// [LiquidGlassSheet.show] with the sheet engine pointed at this file.
LiquidGlassSheetHandle<T> _show<T>(
  BuildContext context, {
  required String name,
  Map<String, dynamic> arguments = const {},
  List<LiquidGlassSheetDetent> detents = const [
    LiquidGlassSheetDetent.medium,
    LiquidGlassSheetDetent.large,
  ],
  double? cornerRadius,
  bool isModal = false,
}) {
  return LiquidGlassSheet.show<T>(
    context: context,
    name: name,
    arguments: arguments,
    detents: detents,
    cornerRadius: cornerRadius,
    isModal: isModal,
    libraryUri: _libraryUri,
  );
}

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) {
            context = ctx;
            return const Center(child: Text('Host'));
          },
        ),
      ),
    ),
  );
  return context;
}

/// Pumps frames until [handle] closes, then returns its result.
Future<T?> _waitForResult<T>(
  WidgetTester tester,
  LiquidGlassSheetHandle<T> handle, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (handle.isShowing) {
    if (DateTime.now().isAfter(end)) {
      fail('Sheet did not close within $timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return handle.result;
}

Future<void> _wait(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(
      NativeLiquidGlassUtils.supportsNativeSheet,
      isTrue,
      reason: 'Run on an iOS 15+ simulator to exercise the native sheet',
    );
    await LiquidGlassSheet.prewarm(libraryUri: _libraryUri);
    // An app prewarms at launch, well before the first tap.
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  testWidgets('sheet content returns a value to the host', (tester) async {
    final context = await _pumpHost(tester);

    final handle = _show<String>(
      context,
      name: 'autoPick',
      arguments: {'value': 'Khmer'},
    );

    expect(await _waitForResult(tester, handle), 'Khmer');
  });

  testWidgets('host dismisses the sheet with a value', (tester) async {
    final context = await _pumpHost(tester);

    final handle = _show<String>(context, name: 'idle');
    // Long enough for the sheet engine to start and render.
    await _wait(tester, const Duration(seconds: 3));
    // Marker for capturing a simulator screenshot of the open sheet.
    debugPrint('SHEET_OPEN');
    await _wait(tester, const Duration(seconds: 4));
    expect(handle.isShowing, isTrue);

    await handle.dismiss('fromHost');

    expect(await _waitForResult(tester, handle), 'fromHost');
  });

  testWidgets('structured arguments and results round-trip', (tester) async {
    final context = await _pumpHost(tester);

    final handle = _show<Object>(
      context,
      name: 'autoPick',
      arguments: {
        'value': {
          'id': 7,
          'tags': ['a', 'b'],
          'ok': true,
        },
      },
      detents: const [
        LiquidGlassSheetDetent.height(320),
        LiquidGlassSheetDetent.fraction(0.6),
      ],
      cornerRadius: 28,
      isModal: true,
    );

    final result = await _waitForResult(tester, handle) as Map;
    expect(result['id'], 7);
    expect(result['tags'], ['a', 'b']);
    expect(result['ok'], true);
  });

  testWidgets('sheets can be opened and closed repeatedly', (tester) async {
    final context = await _pumpHost(tester);

    for (var i = 0; i < 3; i++) {
      final handle = _show<int>(
        context,
        name: 'autoPick',
        arguments: {'value': i, 'delayMs': 200},
      );
      expect(await _waitForResult(tester, handle), i);
      // Let the dismissal animation finish before presenting again.
      await _wait(tester, const Duration(milliseconds: 600));
    }
  });

  testWidgets('unknown sheet name still opens and can be dismissed', (
    tester,
  ) async {
    final context = await _pumpHost(tester);

    final handle = _show<String>(context, name: 'doesNotExist');
    await _wait(tester, const Duration(seconds: 2));
    expect(handle.isShowing, isTrue);

    await handle.dismiss();

    expect(await _waitForResult(tester, handle), isNull);
  });
}
