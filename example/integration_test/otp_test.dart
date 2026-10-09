// OTP inputs on iOS 26+: native glass boxes and the otp text field type.
//
//   cd example && flutter test integration_test/otp_test.dart -d <iOS 26 simulator>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:native_liquid_glass_example/pages/liquid_glass_otp_preview_page.dart';

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('otp boxes style: verify, error, keyboard', (tester) async {
    expect(NativeLiquidGlassUtils.supportsLiquidGlass, isTrue);
    await tester.pumpWidget(
      MaterialApp(home: LiquidGlassOtpPreviewPage(onThemeChanged: (_) {})),
    );
    await _pumpFor(tester, 1200);

    final otp = find.byKey(const ValueKey('otpBoxes'));

    // Correct code fills the boxes and completes.
    await tester.tap(find.text('Fill from code'));
    await _pumpFor(tester, 800);
    expect(find.text('Verified ✓'), findsOneWidget);
    debugPrint('SHOT_VERIFIED');
    await _pumpFor(tester, 1200);

    // Wrong code: error state (red borders + shake).
    await tester.tap(find.text('Clear'));
    await _pumpFor(tester, 400);
    final state = tester.state(find.byType(LiquidGlassOtpPreviewPage));
    expect(state, isNotNull);
    final controller = (tester.widget<LiquidGlassTextField>(otp)).controller!;
    controller.text = '111111';
    await _pumpFor(tester, 900);
    expect(find.text('Enter the code again'), findsOneWidget);
    debugPrint('SHOT_ERROR');
    await _pumpFor(tester, 1200);

    // Focusing the field focuses the hidden native input: keyboard opens.
    // (Test taps are Flutter-level and don't reach native views; a real tap
    // on the boxes focuses natively and reports back the same way.)
    await tester.tap(find.text('Clear'));
    await _pumpFor(tester, 300);
    tester
        .widget<Focus>(
          find.descendant(of: otp, matching: find.byType(Focus)).first,
        )
        .focusNode!
        .requestFocus();
    var keyboard = false;
    for (var i = 0; i < 60 && !keyboard; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      keyboard = tester.view.viewInsets.bottom > 0;
    }
    expect(keyboard, isTrue, reason: 'keyboard did not open on tap');
    await _pumpFor(tester, 800);
    debugPrint('SHOT_KEYBOARD');
    await _pumpFor(tester, 1200);
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(tester, 800);
  });

  testWidgets('otp text field type opens the keyboard', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final completed = <String>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LiquidGlassTextField(
                controller: controller,
                focusNode: node,
                label: 'Verification code',
                textFieldType: LiquidGlassTextFieldType.otp,
                onCompleted: completed.add,
              ),
            ),
          ),
        ),
      ),
    );
    await _pumpFor(tester, 1000);

    controller.text = '654321';
    await _pumpFor(tester, 300);
    expect(completed, ['654321']);

    node.requestFocus();
    var keyboard = false;
    for (var i = 0; i < 60 && !keyboard; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      keyboard = tester.view.viewInsets.bottom > 0;
    }
    expect(keyboard, isTrue);
    await _pumpFor(tester, 800);
    debugPrint('SHOT_FIELD_KEYBOARD');
    await _pumpFor(tester, 1200);
    node.unfocus();
    await _pumpFor(tester, 800);
  });
}
