// A LiquidGlassTextField's Flutter box follows the native field when
// validation shows or clears an error, so widgets below move with it instead
// of being overlapped. iOS 26+.
//
//   cd example && flutter test integration_test/text_field_validation_test.dart -d <iOS 26 simulator>

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiquidGlassTextField(
                key: const ValueKey('field'),
                label: 'Email',
                hint: 'you@example.com',
                errorText: error,
              ),
              const Text('below', key: ValueKey('below')),
              TextButton(
                onPressed: () => setState(
                  () => error = error == null
                      ? 'Please enter a valid email address, for example name@example.com, so we can send your receipt'
                      : null,
                ),
                child: const Text('toggle error'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('box grows and shrinks with the native error row', (
    tester,
  ) async {
    expect(NativeLiquidGlassUtils.supportsLiquidGlass, isTrue);
    await tester.pumpWidget(const MaterialApp(home: _Form()));
    await _pumpFor(tester, 1200);

    final field = find.byKey(const ValueKey('field'));
    final below = find.byKey(const ValueKey('below'));
    final noError = tester.getSize(field).height;

    // Marker for screen recording (see the sync check in the PR notes).
    debugPrint('RECORD_START');
    await _pumpFor(tester, 1500);
    await tester.tap(find.text('toggle error'));
    // Record the box height every frame of the change.
    final heights = <String>[];
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      heights.add(tester.getSize(field).height.toStringAsFixed(1));
    }
    await _pumpFor(tester, 500);
    final withError = tester.getSize(field).height;
    debugPrint('VALIDATION frames: ${heights.join(' ')}');
    debugPrint('VALIDATION noError=$noError withError=$withError');
    debugPrint('SHOT_ERROR');
    await _pumpFor(tester, 1500);

    // The box must grow by the error row, and "below" sits under it.
    expect(withError, greaterThan(noError + 10));
    expect(
      tester.getRect(below).top,
      greaterThanOrEqualTo(tester.getRect(field).bottom),
    );

    await tester.tap(find.text('toggle error'));
    await _pumpFor(tester, 800);
    final cleared = tester.getSize(field).height;
    debugPrint('VALIDATION cleared=$cleared');
    expect(cleared, closeTo(noError, 1));
  });

  testWidgets('a late size report from before the error cleared is ignored', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _Form()));
    await _pumpFor(tester, 1200);
    final field = find.byKey(const ValueKey('field'));
    final noError = tester.getSize(field).height;

    // Show the error, then clear it, like validation while typing.
    await tester.tap(find.text('toggle error'));
    await _pumpFor(tester, 800);
    final withError = tester.getSize(field).height;
    await tester.tap(find.text('toggle error'));
    await _pumpFor(tester, 800);

    // Native measured its layout with the error row still showing, and that
    // report arrives after validation cleared the error. It carries the
    // revision of the config it was measured for (the first one).
    // The page's only platform view is this field.
    final view = tester.allRenderObjects.whereType<RenderUiKitView>().single;
    final channel = 'liquid-glass-text-field-view/${view.viewController.id}';
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onSizeChanged', {
              'height': withError,
              'width': 400.0,
              'revision': 0,
            }),
          ),
          (_) {},
        );
    await _pumpFor(tester, 600);

    final after = tester.getSize(field).height;
    debugPrint('VALIDATION stale report: withError=$withError after=$after');
    expect(after, closeTo(noError, 1));
  });
}
