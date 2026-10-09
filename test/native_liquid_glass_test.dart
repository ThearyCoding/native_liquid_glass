import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

void _noop(int _) {}

void main() {
  testWidgets('tab bar returns empty fallback on non-iOS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: LiquidGlassTabBar(
                items: const [
                  LiquidGlassTabItem(icon: NativeLiquidGlassIcon.iconData(Icons.home_outlined), label: 'Home'),
                  LiquidGlassTabItem(icon: NativeLiquidGlassIcon.iconData(Icons.search_rounded), label: 'Search'),
                ],
                currentIndex: 0,
                onTabSelected: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsNothing);
    expect(find.text('Search'), findsNothing);
  });

  test('device qualification utility returns false on non-iOS test runtime', () {
    final isQualified = NativeLiquidGlassUtils.supportsLiquidGlass;
    expect(isQualified, isFalse);
  });

  group('NativeLiquidGlassUtils.usesNativeViews', () {
    tearDown(() {
      NativeLiquidGlassUtils.debugUsesNativeViewsOverride = null;
      NativeLiquidGlassUtils.debugSupportsLiquidGlassOverride = null;
    });

    test('is false on the non-iOS test runtime', () {
      expect(NativeLiquidGlassUtils.usesNativeViews, isFalse);
    });

    test('starts at iOS 16, below Liquid Glass', () {
      expect(NativeLiquidGlassUtils.minimumNativeIOSVersion, 16);
    });

    test('follows the Liquid Glass override, and its own override wins', () {
      NativeLiquidGlassUtils.debugSupportsLiquidGlassOverride = true;
      expect(NativeLiquidGlassUtils.usesNativeViews, isTrue);
      NativeLiquidGlassUtils.debugUsesNativeViewsOverride = false;
      expect(NativeLiquidGlassUtils.usesNativeViews, isFalse);
    });
  });

  testWidgets('tab bar remains empty with showLabels false on non-iOS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: LiquidGlassTabBar(
                items: const [
                  LiquidGlassTabItem(icon: NativeLiquidGlassIcon.iconData(Icons.home_outlined), label: 'Home'),
                  LiquidGlassTabItem(icon: NativeLiquidGlassIcon.iconData(Icons.search_rounded), label: 'Search'),
                ],
                currentIndex: 0,
                onTabSelected: _noop,
                showLabels: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsNothing);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('tab bar accepts iOS action button config', (tester) async {
    var actionTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: LiquidGlassTabBar(
                items: const [
                  LiquidGlassTabItem(icon: NativeLiquidGlassIcon.iconData(Icons.home_outlined), label: 'Home'),
                  LiquidGlassTabItem(icon: NativeLiquidGlassIcon.iconData(Icons.search_rounded), label: 'Search'),
                ],
                iosActionButton: const LiquidGlassTabItem(icon: NativeLiquidGlassIcon.sfSymbol('plus'), label: 'Add'),
                currentIndex: 0,
                onTabSelected: _noop,
                onActionButtonPressed: () {
                  actionTapCount++;
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsNothing);
    expect(find.text('Search'), findsNothing);
    expect(actionTapCount, 0);
  });

  testWidgets('tab items accept per-item icon size and selected color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: LiquidGlassTabBar(
                items: const [
                  LiquidGlassTabItem(
                    icon: NativeLiquidGlassIcon.iconData(Icons.home_outlined),
                    label: 'Home',
                    iconSize: 22,
                    selectedItemColor: Color(0xFFFF6B6B),
                  ),
                  LiquidGlassTabItem(
                    icon: NativeLiquidGlassIcon.iconData(Icons.search_rounded),
                    label: 'Search',
                    iconSize: 28,
                    selectedItemColor: Color(0xFF4CD964),
                  ),
                ],
                currentIndex: 0,
                onTabSelected: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsNothing);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('liquid glass button renders fallback and handles taps', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassButton(
              label: 'Continue',
              onPressed: () {
                tapCount++;
              },
              icon: const NativeLiquidGlassIcon.iconData(Icons.arrow_forward_rounded),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets('liquid glass icon button renders fallback and handles taps', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassButton.icon(
              onPressed: () {
                tapCount++;
              },
              icon: const NativeLiquidGlassIcon.iconData(Icons.favorite_border_rounded),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  test('liquid glass button accepts expanded icon and color parameters', () {
    final button = LiquidGlassButton(
      label: 'Continue',
      onPressed: () {},
      icon: const NativeLiquidGlassIcon.asset('assets/icons/continue.svg'),
      iconColor: const Color(0xFFFF6B6B),
      foregroundColor: const Color(0xFF111111),
      tint: const Color(0xFF4CD964),
      imagePadding: 12,
      interactive: true,
    );

    expect(button.icon?.assetPath, 'assets/icons/continue.svg');
    expect(button.iconColor, const Color(0xFFFF6B6B));
    expect(button.foregroundColor, const Color(0xFF111111));
    expect(button.tint, const Color(0xFF4CD964));
    expect(button.imagePadding, 12);
    expect(button.interactive, isTrue);
    expect(button.width, isNull);
    expect(button.height, isNull);
  });

  testWidgets('liquid glass button wraps content size when width and height are omitted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: LiquidGlassButton(label: 'Go', onPressed: () {}),
          ),
        ),
      ),
    );

    final fallbackButtonFinder = find.byType(FilledButton);
    expect(fallbackButtonFinder, findsOneWidget);

    final fallbackButtonSize = tester.getSize(fallbackButtonFinder);
    expect(fallbackButtonSize.width, lessThan(220));
    expect(fallbackButtonSize.width, greaterThan(40));
    expect(fallbackButtonSize.height, greaterThan(30));
  });

  testWidgets('liquid glass icon button supports SF Symbol only source', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassButton.icon(
              onPressed: () {
                tapCount++;
              },
              icon: const NativeLiquidGlassIcon.sfSymbol('heart'),
              iconColor: const Color(0xFFFF375F),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets('liquid glass button disabled state does not invoke callback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassButton(label: 'Continue', onPressed: null, icon: const NativeLiquidGlassIcon.iconData(Icons.arrow_forward_rounded)),
          ),
        ),
      ),
    );

    final fallbackButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(fallbackButton.onPressed, isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  });

  testWidgets('liquid glass icon button disabled state does not invoke callback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: LiquidGlassButton.icon(onPressed: null, icon: const NativeLiquidGlassIcon.iconData(Icons.favorite_border_rounded))),
        ),
      ),
    );

    final fallbackIconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(fallbackIconButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();
  });

  group('LiquidGlassTextField Flutter TextField parity (fallback)', () {
    testWidgets('external controller drives the field and typing updates the controller', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'hello');
      addTearDown(controller.dispose);
      var lastChanged = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassTextField(
              controller: controller,
              onChanged: (value) => lastChanged = value,
            ),
          ),
        ),
      );

      expect(find.text('hello'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello world');
      await tester.pump();

      expect(controller.text, 'hello world');
      expect(lastChanged, 'hello world');

      controller.text = 'set externally';
      await tester.pump();
      expect(find.text('set externally'), findsOneWidget);
    });

    testWidgets('external focusNode drives native focus state', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiquidGlassTextField(focusNode: focusNode)),
        ),
      );

      expect(focusNode.hasFocus, isFalse);

      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      focusNode.unfocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('onSubmitted and onEditingComplete fire on submit', (tester) async {
      String? submittedValue;
      var editingCompleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassTextField(
              onSubmitted: (value) => submittedValue = value,
              onEditingComplete: () => editingCompleteCount++,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'submit me');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submittedValue, 'submit me');
      expect(editingCompleteCount, 1);
    });

    testWidgets('textAlign, textCapitalization, autocorrect and cursorColor pass through', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassTextField(
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.words,
              autocorrect: false,
              enableSuggestions: false,
              cursorColor: const Color(0xFF112233),
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textAlign, TextAlign.center);
      expect(field.textCapitalization, TextCapitalization.words);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.cursorColor, const Color(0xFF112233));
    });

    testWidgets('swapping controller instance mid-lifetime updates displayed text', (
      tester,
    ) async {
      final controllerA = TextEditingController(text: 'A');
      final controllerB = TextEditingController(text: 'B');
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);

      var useA = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  LiquidGlassTextField(controller: useA ? controllerA : controllerB),
                  TextButton(
                    onPressed: () => setState(() => useA = !useA),
                    child: const Text('swap'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);

      await tester.tap(find.text('swap'));
      await tester.pumpAndSettle();

      expect(find.text('B'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });
  });
}
