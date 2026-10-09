import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_liquid_glass_example/pages/liquid_glass_text_field_preview_page.dart';

/// Reproduces the ListView-recycling scenario from
/// `ai_review/Screen Recording 2026-09-22 at 2.28.40 PM.mov`: scroll a
/// labelled native field out past the cache extent (disposing its State)
/// and back (rebuilding it fresh), and confirm no exception / overflow is
/// thrown by the label-bleed height estimate.
///
/// Markers are printed so an external screenshot can be taken during each
/// deliberate pause.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scroll recycling does not bleed native label over headers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiquidGlassTextFieldPreviewPage()),
    );
    await tester.pumpAndSettle();

    debugPrint('SCROLL_TEST: PHASE1_READY (initial, top of list)');
    await Future<void>.delayed(const Duration(seconds: 15));

    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);

    // Scroll far down -- past the cache extent -- so the early labelled
    // fields ("Full Name", "First Name (controller)", ...) get disposed.
    for (var i = 0; i < 10; i++) {
      await tester.drag(listFinder, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    debugPrint('SCROLL_TEST: PHASE2_READY (scrolled far down)');
    await Future<void>.delayed(const Duration(seconds: 15));

    // Scroll back up so those fields rebuild with a fresh State -- this is
    // exactly the moment the old code fell back to the under-estimated
    // height and the label bled over the section header above it.
    for (var i = 0; i < 10; i++) {
      await tester.drag(listFinder, const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    debugPrint('SCROLL_TEST: PHASE3_READY (scrolled back to top)');
    await Future<void>.delayed(const Duration(seconds: 15));

    debugPrint('SCROLL_TEST: DONE');
  });
}
