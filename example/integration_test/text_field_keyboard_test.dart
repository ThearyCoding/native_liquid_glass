// LiquidGlassTextField scrolls itself above the keyboard like Flutter's
// TextField: it follows the keyboard frame by frame while it opens, glides
// into view when focus moves with the keyboard open, and keeps
// `scrollPadding` free. iOS 26+, software keyboard enabled in the simulator.
//
//   cd example && flutter test integration_test/text_field_keyboard_test.dart -d <iOS 26 simulator>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('field follows the keyboard and keeps scrollPadding free', (
    tester,
  ) async {
    expect(NativeLiquidGlassUtils.supportsLiquidGlass, isTrue);
    final nodes = List.generate(15, (_) => FocusNode());
    addTearDown(() {
      for (final n in nodes) {
        n.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Keyboard')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < nodes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: LiquidGlassTextField(
                    key: ValueKey('field$i'),
                    focusNode: nodes[i],
                    hint: 'Field $i',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final view = tester.view;
    double keyboardTop() =>
        (view.physicalSize.height - view.viewInsets.bottom) /
        view.devicePixelRatio;

    // Pick the field closest to the bottom of the screen that is still fully
    // visible: the keyboard will cover it.
    final screenBottom = view.physicalSize.height / view.devicePixelRatio;
    var target = 0;
    for (var i = 0; i < nodes.length; i++) {
      final f = find.byKey(ValueKey('field$i'));
      if (f.evaluate().isEmpty) break;
      if (tester.getRect(f).bottom < screenBottom - 40) target = i;
    }
    final field = find.byKey(ValueKey('field$target'), skipOffstage: false);

    // 1. Keyboard opening: track every frame of its animation.
    nodes[target].requestFocus();
    var maxCovered = 0.0;
    var sawKeyboard = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (view.viewInsets.bottom > 0) sawKeyboard = true;
      final covered = tester.getRect(field).bottom - keyboardTop();
      if (covered > maxCovered) maxCovered = covered;
    }
    expect(sawKeyboard, isTrue, reason: 'software keyboard did not open');
    final gap = keyboardTop() - tester.getRect(field).bottom;
    debugPrint(
      'KEYBOARD field$target maxCoveredDuringOpen=${maxCovered.toStringAsFixed(1)} '
      'finalGap=${gap.toStringAsFixed(1)}',
    );
    // Never hidden by the keyboard while it opens (the native field would
    // lose focus if it left the screen), and settles with scrollPadding (20)
    // free above the keyboard.
    expect(maxCovered, lessThanOrEqualTo(1));
    expect(gap, closeTo(20, 1.5));

    // 2. Keyboard already open: focus a field the keyboard is covering.
    final next = target + 2;
    final nextField = find.byKey(ValueKey('field$next'), skipOffstage: false);
    nodes[next].requestFocus();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final nextGap = keyboardTop() - tester.getRect(nextField).bottom;
    debugPrint(
      'KEYBOARD field$next gapAfterGlide=${nextGap.toStringAsFixed(1)}',
    );
    expect(nextGap, closeTo(20, 1.5));
    debugPrint('SHOT_KEYBOARD');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    FocusManager.instance.primaryFocus?.unfocus();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });
}
