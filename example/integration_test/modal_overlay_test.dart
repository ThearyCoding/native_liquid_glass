// Native glass that stays visible under a Flutter modal (forceShow) must not
// draw its shadow over the modal. Screenshot-based. iOS 26+.
//
//   cd example && flutter test integration_test/modal_overlay_test.dart -d <iOS 26 simulator>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:native_liquid_glass_example/pages/liquid_glass_tab_bar_preview_page.dart';

Future<void> _settle(WidgetTester tester, [int ms = 1000]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tab bar shadow does not show over a Flutter bottom sheet', (
    tester,
  ) async {
    expect(NativeLiquidGlassUtils.supportsLiquidGlass, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [LiquidGlassNavigatorObserver()],
        home: LiquidGlassTabBarPreviewPage(onThemeChanged: (_) {}),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Show Bottom Sheet'));
    await _settle(tester, 1200);
    final bar = tester.getRect(find.byType(LiquidGlassTabBar));
    debugPrint('MODAL tabBar=$bar');
    debugPrint('SHOT_MODAL');
    await _settle(tester, 1500);

    // Closing the sheet restores the tab bar (and its shadow) as before.
    await tester.tapAt(const Offset(200, 150));
    await _settle(tester, 1200);
    debugPrint('SHOT_AFTER');
    await _settle(tester, 1500);
  });
}
