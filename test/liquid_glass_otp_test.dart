import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

// Widget tests run the Flutter fallback (no native views in tests).
void main() {
  group('LiquidGlassTextField otp type', () {
    Future<List<String>> pumpField(
      WidgetTester tester, {
      int? maxLength,
      required List<String> completed,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidGlassTextField(
              textFieldType: LiquidGlassTextFieldType.otp,
              maxLength: maxLength,
              onCompleted: completed.add,
            ),
          ),
        ),
      );
      return completed;
    }

    testWidgets('uses the number pad and one-time-code autofill', (
      tester,
    ) async {
      await pumpField(tester, completed: []);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
      expect(field.autofillHints, [AutofillHints.oneTimeCode]);
      expect(field.maxLength, 6);
    });

    testWidgets('keeps digits only and completes once at 6', (tester) async {
      final completed = await pumpField(tester, completed: []);

      await tester.enterText(find.byType(TextField), '12a3');
      expect(find.text('123'), findsOneWidget);
      expect(completed, isEmpty);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(completed, ['123456']);

      // Rebuilds don't fire it again; editing and completing again does.
      await tester.pump();
      expect(completed, ['123456']);
      await tester.enterText(find.byType(TextField), '12345');
      await tester.enterText(find.byType(TextField), '123459');
      expect(completed, ['123456', '123459']);
    });

    testWidgets('honours a custom length', (tester) async {
      final completed = await pumpField(tester, maxLength: 4, completed: []);
      await tester.enterText(find.byType(TextField), '9876');
      expect(completed, ['9876']);
    });
  });

  group('LiquidGlassTextField otp boxes (fallback)', () {
    Text box(WidgetTester tester, int index) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(AnimatedContainer),
            matching: find.byType(Text),
          ),
        )
        .elementAt(index);

    Widget boxesField({
      TextEditingController? controller,
      int? maxLength,
      bool obscureText = false,
      String? errorText,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onCompleted,
    }) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassTextField(
            controller: controller,
            label: 'Code',
            textFieldType: LiquidGlassTextFieldType.otp,
            otpStyle: LiquidGlassOtpStyle.boxes,
            maxLength: maxLength,
            obscureText: obscureText,
            errorText: errorText,
            onChanged: onChanged,
            onCompleted: onCompleted,
          ),
        ),
      ),
    );

    testWidgets('fills one box per digit and completes when full', (
      tester,
    ) async {
      final changed = <String>[];
      final completed = <String>[];
      await tester.pumpWidget(
        boxesField(onChanged: changed.add, onCompleted: completed.add),
      );
      expect(find.byType(AnimatedContainer), findsNWidgets(6));
      expect(find.text('Code'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '42');
      await tester.pump();
      expect(box(tester, 0).data, '4');
      expect(box(tester, 1).data, '2');
      expect(box(tester, 2).data, '');
      expect(changed.last, '42');
      expect(completed, isEmpty);

      await tester.enterText(find.byType(TextField), '429173');
      await tester.pump();
      expect(box(tester, 5).data, '3');
      expect(completed, ['429173']);
    });

    testWidgets('maxLength sets the number of boxes; digits only', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(boxesField(controller: controller, maxLength: 4));
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
      await tester.enterText(find.byType(TextField), '1a2b3c4d5');
      await tester.pump();
      expect(controller.text, '1234');
    });

    testWidgets('shows text set through the controller', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final completed = <String>[];
      await tester.pumpWidget(
        boxesField(controller: controller, onCompleted: completed.add),
      );
      controller.text = '555123';
      await tester.pump();
      expect(box(tester, 0).data, '5');
      expect(box(tester, 5).data, '3');
      expect(completed, ['555123']);
    });

    testWidgets('boxes fill the width edge to edge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LiquidGlassTextField(
                textFieldType: LiquidGlassTextFieldType.otp,
                otpStyle: LiquidGlassOtpStyle.boxes,
                maxLength: 4,
              ),
            ),
          ),
        ),
      );
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final first = tester.getRect(find.byType(AnimatedContainer).first);
      final last = tester.getRect(find.byType(AnimatedContainer).last);
      // Flush with both padded edges, so centered.
      expect(first.left, closeTo(16, 0.5));
      expect(last.right, closeTo(screenWidth - 16, 0.5));
      // Equal widths, height capped at 56 on a wide test screen.
      expect(first.width, closeTo(last.width, 0.5));
      expect(first.height, 56);
    });

    testWidgets('boxes follow the field style', (tester) async {
      BoxDecoration firstBox() =>
          tester
                  .widget<AnimatedContainer>(
                    find.byType(AnimatedContainer).first,
                  )
                  .decoration!
              as BoxDecoration;

      Future<void> pumpStyle(LiquidGlassTextFieldStyle style) =>
          tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LiquidGlassTextField(
                  textFieldType: LiquidGlassTextFieldType.otp,
                  otpStyle: LiquidGlassOtpStyle.boxes,
                  style: style,
                ),
              ),
            ),
          );

      await pumpStyle(LiquidGlassTextFieldStyle.underlined);
      final underlined = firstBox();
      expect(underlined.color, isNull);
      expect((underlined.border! as Border).top, BorderSide.none);
      expect((underlined.border! as Border).bottom.width, 1);

      await pumpStyle(LiquidGlassTextFieldStyle.plain);
      final plain = firstBox();
      expect(plain.color, isNull);
      expect((plain.border! as Border).top.width, 1);

      await pumpStyle(LiquidGlassTextFieldStyle.rounded);
      expect(firstBox().color, isNotNull);
    });

    testWidgets('obscureText shows dots and errorText shows the error', (
      tester,
    ) async {
      await tester.pumpWidget(
        boxesField(obscureText: true, errorText: 'Wrong code'),
      );
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(box(tester, 0).data, '●');
      expect(find.text('Wrong code'), findsOneWidget);
    });
  });
}
