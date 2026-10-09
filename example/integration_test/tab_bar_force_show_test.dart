// The native tab bar implements `setForceShow`, so toggling
// `LiquidGlassTabBar.forceShow` works without a MissingPluginException. iOS 26+.
//
//   cd example && flutter test integration_test/tab_bar_force_show_test.dart -d <iOS 26 simulator>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

Future<void> _settle(WidgetTester tester, [int ms = 800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _page(bool forceShow) => Scaffold(
  body: const Center(child: Text('Body')),
  bottomNavigationBar: LiquidGlassTabBar(
    forceShow: forceShow,
    currentIndex: 0,
    onTabSelected: (_) {},
    items: const [
      LiquidGlassTabItem(
        icon: NativeLiquidGlassIcon.sfSymbol('house'),
        label: 'Home',
      ),
      LiquidGlassTabItem(
        icon: NativeLiquidGlassIcon.sfSymbol('gear'),
        label: 'Settings',
      ),
    ],
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('forceShow syncs to the native tab bar', (tester) async {
    expect(NativeLiquidGlassUtils.supportsLiquidGlass, isTrue);

    // Record every forceShow call the tab bar makes and its native answer.
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
      original(message, wrapWidth: wrapWidth);
    };
    addTearDown(() => debugPrint = original);

    await tester.pumpWidget(MaterialApp(home: _page(false)));
    await _settle(tester);
    await tester.pumpWidget(MaterialApp(home: _page(true)));
    await _settle(tester);

    // Navigate away and back with forceShow on.
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await _settle(tester);
    nav.pop();
    await _settle(tester);

    await tester.pumpWidget(MaterialApp(home: _page(false)));
    await _settle(tester);

    final errors = logs.where((l) => l.contains('Error syncing forceShow'));
    expect(errors, isEmpty);
    expect(tester.takeException(), isNot(isA<MissingPluginException>()));
  });
}
