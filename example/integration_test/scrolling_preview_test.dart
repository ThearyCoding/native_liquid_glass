// Native Liquid Glass widgets inside Flutter scroll views move, size and clip
// with the Flutter content around them. iOS 26+.
//
//   cd example && flutter test integration_test/scrolling_preview_test.dart -d <iOS 26 simulator>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:native_liquid_glass_example/pages/liquid_glass_scrolling_preview_page.dart';

Future<void> _settle(WidgetTester tester, [int ms = 1000]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Drags [from] by [delta] and holds it there, printing a screenshot marker.
Future<TestGesture> _dragAndHold(
  WidgetTester tester,
  Finder from,
  Offset delta,
  String shot,
) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(delta / 10);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _settle(tester, 500);
  debugPrint('SHOT_$shot');
  await _settle(tester, 1500);
  return gesture;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native widgets follow every scroll view', (tester) async {
    expect(NativeLiquidGlassUtils.supportsLiquidGlass, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidGlassScrollingPreviewPage(onThemeChanged: (_) {}),
      ),
    );
    await _settle(tester);

    // ListView: a native button moves exactly as far as its row's text.
    final label = find.text('Row 4');
    final button = find.ancestor(
      of: find.text('Row 4'),
      matching: find.byType(ListTile),
    );
    final glass = find.descendant(
      of: button,
      matching: find.byType(LiquidGlassButton),
    );
    final labelBefore = tester.getRect(label);
    final glassBefore = tester.getRect(glass);
    var gesture = await _dragAndHold(
      tester,
      label,
      const Offset(0, -200),
      'LIST',
    );
    final labelDy = tester.getRect(label).top - labelBefore.top;
    final glassDy = tester.getRect(glass).top - glassBefore.top;
    debugPrint('SCROLL list label dy=$labelDy glass dy=$glassDy');
    expect(glassDy, closeTo(labelDy, 0.5));
    await gesture.up();
    await _settle(tester);

    // CustomScrollView: pinned header, sliver grid of glass containers.
    await tester.tap(find.text('CustomScrollView'));
    await _settle(tester);
    gesture = await _dragAndHold(
      tester,
      find.text('Glass card 0'),
      const Offset(0, -260),
      'CUSTOM',
    );
    await gesture.up();
    await _settle(tester);

    // GridView of glass containers with buttons inside.
    await tester.tap(find.text('GridView'));
    await _settle(tester);
    gesture = await _dragAndHold(
      tester,
      find.text('Item 2'),
      const Offset(0, -300),
      'GRID',
    );
    await gesture.up();
    await _settle(tester);

    // Horizontal lists inside a vertical list.
    await tester.tap(find.text('Horizontal'));
    await _settle(tester);
    gesture = await _dragAndHold(
      tester,
      // Button labels are drawn natively, so drag the list itself.
      find
          .byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.horizontal,
          )
          .first,
      const Offset(-220, 0),
      'HORIZONTAL',
    );
    await gesture.up();
    await _settle(tester);
  });
}
