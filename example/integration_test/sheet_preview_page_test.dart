// Drives the real LiquidGlassSheet preview page with native sheets.
//
// Run with `flutter drive` so this file is the app's root library and the
// sheet engine finds `bottomSheetMain` here, exactly like in the real app:
//
//   cd example && flutter drive -d <iOS simulator> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/sheet_preview_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:native_liquid_glass_example/demo_app.dart';
import 'package:native_liquid_glass_example/sheets/demo_sheets.dart';

// ─── BOTTOM SHEET ENTRY POINT ───
// The demo sheets, each wrapped in a script that acts for the user inside the
// sheet's own engine (the host test can't tap into another engine).
@pragma('vm:entry-point')
void bottomSheetMain(List<String> args) {
  runLiquidGlassSheet(
    args,
    builders: {
      for (final entry in demoSheetBuilders.entries)
        entry.key: (context, arguments) => _ScriptedSheet(
          name: entry.key,
          arguments: arguments,
          child: entry.value(context, arguments),
        ),
    },
  );
}

class _ScriptedSheet extends StatefulWidget {
  final String name;
  final Map<String, dynamic> arguments;
  final Widget child;

  const _ScriptedSheet({
    required this.name,
    required this.arguments,
    required this.child,
  });

  @override
  State<_ScriptedSheet> createState() => _ScriptedSheetState();
}

class _ScriptedSheetState extends State<_ScriptedSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final sheet = LiquidGlassSheetScope.of(context);
    switch (widget.name) {
      case LanguagePickerSheet.name:
        // Stay open past the "dismiss from host" demo's 3 s timer, then pick
        // a language with a real tap on the list tile.
        await Future<void>.delayed(const Duration(milliseconds: 4500));
        await LiveWidgetController(
          WidgetsBinding.instance,
        ).tap(find.text('Khmer'));
      case DetailsSheet.name:
        await Future<void>.delayed(const Duration(seconds: 1));
        // The demo's sheet is closed by the user before its timer fires.
        sheet.dismiss(
          widget.arguments.containsKey('closesIn') ? 'closed by user' : 42,
        );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  void Function()? onFrame,
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 50));
    onFrame?.call();
  }
}

/// Pumps frames for [duration] (pumpAndSettle can't settle with native views).
Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preview page: results come back and nothing is closed by host', (
    tester,
  ) async {
    expect(NativeLiquidGlassUtils.supportsNativeSheet, isTrue);

    await tester.pumpWidget(const LiquidGlassDemoApp());
    await tester.pump();
    await LiquidGlassSheet.prewarm();

    final entry = find.text('LiquidGlassSheet preview');
    await tester.scrollUntilVisible(
      entry,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await _pumpUntil(tester, find.text('Interactive sheet'));
    // Let the page finish sliding in before tapping its buttons.
    await _pumpFor(tester, const Duration(seconds: 1));

    // 1. A sheet returns a value to the page.
    await tester.tap(find.text('Interactive sheet'));
    await _pumpUntil(tester, find.text('Last result: 42'));

    // 2. Open the "dismiss from host" demo; the user closes it at 1 s.
    await tester.tap(find.text('Auto-close after 3s (demo)'));
    await _pumpUntil(tester, find.text('Last result: closed by user'));

    // 3. Open the language picker right away. The demo's 3 s timer fires
    //    while it is open and must not close it.
    await tester.tap(find.text('Language picker (English)'));
    var closedByHost = false;
    await _pumpUntil(
      tester,
      find.text('Last result: Khmer'),
      onFrame: () {
        if (find
            .text('Last result: auto-closed after 3s')
            .evaluate()
            .isNotEmpty) {
          closedByHost = true;
        }
      },
    );
    expect(closedByHost, isFalse, reason: 'language picker was closed by host');
    expect(find.text('Language picker (Khmer)'), findsOneWidget);
  });
}
