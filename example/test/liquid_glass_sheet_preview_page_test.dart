import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:native_liquid_glass_example/pages/liquid_glass_sheet_preview_page.dart';
import 'package:native_liquid_glass_example/sheets/demo_sheets.dart';

// Runs on the Flutter fallback sheet (no native sheets in widget tests); the
// page's open/close bookkeeping is the same on both.
void main() {
  setUpAll(() => LiquidGlassSheet.registerBuilders(demoSheetBuilders));

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LiquidGlassSheetPreviewPage(onThemeChanged: (_) {})),
    );
  }

  Future<void> closeSheetByTappingOutside(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }

  testWidgets('host timer closes its own sheet when left open', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Auto-close after 3s (demo)'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailsSheet), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(DetailsSheet), findsNothing);
    expect(find.text('Last result: auto-closed after 3s'), findsOneWidget);
  });

  testWidgets('host timer does not close a sheet opened afterwards', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Auto-close after 3s (demo)'));
    await tester.pumpAndSettle();
    await closeSheetByTappingOutside(tester);
    expect(find.byType(DetailsSheet), findsNothing);

    await tester.tap(find.text('Language picker (English)'));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerSheet), findsOneWidget);

    // Past the demo's 3s timer.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byType(LanguagePickerSheet), findsOneWidget);
    expect(find.text('Last result: auto-closed after 3s'), findsNothing);

    await tester.tap(find.text('Khmer'));
    await tester.pumpAndSettle();
    expect(find.text('Last result: Khmer'), findsOneWidget);
    expect(find.text('Language picker (Khmer)'), findsOneWidget);
  });

  testWidgets('host timer does nothing after its sheet was closed', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Auto-close after 3s (demo)'));
    await tester.pumpAndSettle();
    await closeSheetByTappingOutside(tester);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Last result: null'), findsOneWidget);
  });
}
