// Checks that native Liquid Glass views take exactly the space Flutter gives
// them, so Flutter layout positions them like any other widget. iOS 26+.
//
//   cd example && flutter test integration_test/glass_layout_test.dart -d <iOS 26 simulator>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:native_liquid_glass_example/pages/liquid_glass_button_group_preview_page.dart';

List<LiquidGlassButtonData> _buttons() => [
  LiquidGlassButtonData(
    icon: const NativeLiquidGlassIcon.sfSymbol('square.and.arrow.up'),
    onPressed: () {},
  ),
  LiquidGlassButtonData(
    icon: const NativeLiquidGlassIcon.sfSymbol('pencil'),
    onPressed: () {},
  ),
  LiquidGlassButtonData(
    icon: const NativeLiquidGlassIcon.sfSymbol('trash'),
    onPressed: () {},
  ),
];

Widget _groupPage(Axis axis, {Alignment alignment = Alignment.center}) {
  return MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Text('above'),
            Align(
              alignment: alignment,
              child: LiquidGlassButtonGroup(
                key: const ValueKey('group'),
                axis: axis,
                spacing: 0,
                buttons: _buttons(),
              ),
            ),
            const Text('below'),
          ],
        ),
      ),
    ),
  );
}

/// Pumps real frames so native layout and channel round-trips can happen.
Future<void> _settle(WidgetTester tester, [int ms = 1200]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    expect(NativeLiquidGlassUtils.supportsLiquidGlass, isTrue);
  });

  testWidgets('button group box fits its native buttons in both axes', (
    tester,
  ) async {
    final group = find.byKey(const ValueKey('group'));

    await tester.pumpWidget(_groupPage(Axis.horizontal));
    await _settle(tester);
    final horizontal = tester.getSize(group);
    final screenWidth = tester.getSize(find.byType(Scaffold)).width;
    debugPrint('LAYOUT horizontal=$horizontal');
    debugPrint('SHOT_HORIZONTAL');
    await _settle(tester, 1500);

    expect(horizontal.width, lessThan(screenWidth), reason: 'hugs content');
    expect(horizontal.width, greaterThan(horizontal.height * 2));

    // Switching axis must resize the Flutter box to the new native layout.
    await tester.pumpWidget(_groupPage(Axis.vertical));
    await _settle(tester);
    final vertical = tester.getSize(group);
    debugPrint('LAYOUT vertical=$vertical');
    debugPrint('SHOT_VERTICAL');
    await _settle(tester, 1500);

    expect(vertical.height, greaterThan(vertical.width * 2));
    expect(vertical.height, closeTo(horizontal.width, 4));
    expect(vertical.width, closeTo(horizontal.height, 4));

    // Neighbours are laid out around the real size, not overlapped.
    final above = tester.getRect(find.text('above'));
    final below = tester.getRect(find.text('below'));
    final groupRect = tester.getRect(group);
    expect(groupRect.top, greaterThanOrEqualTo(above.bottom));
    expect(below.top, greaterThanOrEqualTo(groupRect.bottom));
  });

  testWidgets('preview page: group pushes the card instead of overlapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidGlassButtonGroupPreviewPage(onThemeChanged: (_) {}),
      ),
    );
    await _settle(tester);
    final group = find.byType(LiquidGlassButtonGroup);
    final label = find.textContaining('Last pressed');

    // Toggle a few times: a stale size reply must never win over a newer one.
    for (var i = 0; i < 3; i++) {
      for (final axis in ['Vertical', 'Horizontal']) {
        await tester.tap(find.text(axis));
        await _settle(tester);
        final g = tester.getRect(group);
        final card = tester.getRect(find.byType(Card));
        debugPrint('LAYOUT page $axis group=$g cardTop=${card.top}');
        if (axis == 'Vertical') {
          expect(g.height, greaterThan(g.width * 2), reason: 'run $i');
        } else {
          expect(g.width, greaterThan(g.height * 2), reason: 'run $i');
        }
        expect(g.top, greaterThanOrEqualTo(tester.getRect(label).bottom));
        expect(card.top, greaterThanOrEqualTo(g.bottom));
        if (i == 0 && axis == 'Vertical') {
          debugPrint('SHOT_PAGE');
          await _settle(tester, 1500);
        }
      }
    }
  });

  testWidgets('button group follows Flutter alignment', (tester) async {
    final group = find.byKey(const ValueKey('group'));

    await tester.pumpWidget(
      _groupPage(Axis.horizontal, alignment: Alignment.centerLeft),
    );
    await _settle(tester);

    expect(tester.getRect(group).left, 0);
    expect(tester.getSize(group).width, lessThan(200));
  });

  testWidgets('text button box matches its native layout', (tester) async {
    Widget page(LiquidGlassImagePlacement placement) => MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('above'),
              LiquidGlassButton(
                key: const ValueKey('button'),
                label: 'Continue',
                icon: const NativeLiquidGlassIcon.sfSymbol('arrow.right'),
                imagePlacement: placement,
                onPressed: () {},
              ),
              const Text('below'),
            ],
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('button'));

    await tester.pumpWidget(page(LiquidGlassImagePlacement.leading));
    await _settle(tester);
    final leading = tester.getSize(button);

    await tester.pumpWidget(page(LiquidGlassImagePlacement.top));
    await _settle(tester);
    final top = tester.getSize(button);
    debugPrint('LAYOUT button leading=$leading top=$top');
    debugPrint('SHOT_BUTTON');
    await _settle(tester, 1500);

    // Icon above the label: taller and narrower than icon beside the label.
    expect(top.height, greaterThan(leading.height));
    expect(top.width, lessThan(leading.width));
    expect(tester.getRect(button).left, 0);
    expect(
      tester.getRect(find.text('below')).top,
      greaterThanOrEqualTo(tester.getRect(button).bottom),
    );
  });

  testWidgets('native buttons scroll with their Flutter rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Scrolling')),
          body: ListView.builder(
            itemCount: 30,
            itemBuilder: (context, i) => ListTile(
              title: Text('Row $i'),
              trailing: LiquidGlassButton(label: 'Btn $i', onPressed: () {}),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    final row = find.text('Row 3');
    final before = tester.getRect(row);
    final gesture = await tester.startGesture(tester.getCenter(row));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _settle(tester, 500);
    debugPrint(
      'LAYOUT scroll row3 before=$before during=${tester.getRect(row)}',
    );
    debugPrint('SHOT_SCROLL');
    await _settle(tester, 1500);
    await gesture.up();
    await _settle(tester, 800);
  });

  testWidgets('AppBar buttons keep their size through push and pop', (
    tester,
  ) async {
    const actions = ['magnifyingglass', 'bell', 'ellipsis'];
    Widget page(String title) => Scaffold(
      appBar: AppBar(
        leading: LiquidGlassButton.icon(
          key: const ValueKey('lead'),
          icon: const NativeLiquidGlassIcon.sfSymbol('chevron.left'),
          onPressed: () {},
        ),
        title: Text(title),
        actions: [
          for (final s in actions)
            LiquidGlassButton.icon(
              key: ValueKey(s),
              icon: NativeLiquidGlassIcon.sfSymbol(s),
              onPressed: () {},
            ),
        ],
      ),
      body: Center(child: Text('$title body')),
    );

    await tester.pumpWidget(MaterialApp(home: page('First')));
    await _settle(tester);

    // Every frame of the transition: no button collapses and the actions keep
    // their spacing, on the page being covered and on the page being revealed.
    void expectStable(String phase) {
      final first = find.byKey(const ValueKey('magnifyingglass')).first;
      final firstLeft = tester.getRect(first).left;
      for (var i = 0; i < actions.length; i++) {
        final r = tester.getRect(find.byKey(ValueKey(actions[i])).first);
        expect(r.width, closeTo(44, 0.5), reason: '$phase ${actions[i]}');
        expect(r.height, closeTo(44, 0.5), reason: '$phase ${actions[i]}');
        expect(r.left - firstLeft, closeTo(i * 44.0, 0.5), reason: phase);
      }
    }

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => page('Second')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      expectStable('push frame $i');
      if (i == 5) {
        debugPrint('SHOT_PUSH');
        await _settle(tester, 1200);
      }
    }
    await _settle(tester, 600);

    nav.pop();
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      expectStable('pop frame $i');
    }
    await _settle(tester, 600);
    expectStable('after pop');
  });

  testWidgets('container child scales with the glass while pressed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassContainer(
              config: const LiquidGlassConfig(
                shape: LiquidGlassEffectShape.capsule,
                interactive: true,
              ),
              width: 200,
              height: 56,
              onTap: () {},
              child: const Center(child: Text('Press me')),
            ),
          ),
        ),
      ),
    );
    await _settle(tester, 600);

    final rest = tester.getRect(find.text('Press me'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Press me')),
    );
    await _settle(tester, 600);
    final pressed = tester.getRect(find.text('Press me'));
    debugPrint('LAYOUT container rest=$rest pressed=$pressed');

    expect(pressed.width / rest.width, closeTo(1.04, 0.01));
    expect(pressed.center.dx, closeTo(rest.center.dx, 0.5));

    await gesture.up();
    await _settle(tester, 800);
    final released = tester.getRect(find.text('Press me'));
    expect(released.width, closeTo(rest.width, 0.5));
  });
}
