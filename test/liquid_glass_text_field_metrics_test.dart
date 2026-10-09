import 'package:flutter_test/flutter_test.dart';
import 'package:native_liquid_glass/src/liquid_glass_text_field_metrics.dart';

/// REPRO (`ai_review/Screen Recording 2026-09-22 at 2.28.40 PM.mov`, 4.8s and
/// 27.2s): a Flutter section header painted on top of the next field's label —
/// "Flutter TextField Parity" over "First Name (controller)", then "Style
/// Variations" over "Plain Field".
///
/// The label is drawn by the NATIVE view (`label:` is a native prop, stacked
/// above the field in `LiquidGlassTextFieldView.body`), while the header is a
/// Flutter `Text`. The native host sets `clipsToBounds = false`, so when the
/// Flutter `SizedBox` is shorter than the native stack the overflow is not
/// cropped — it paints over the Flutter widgets around it.
///
/// The old estimate returned a flat 50 for any single-line field, counting the
/// field box and nothing else, so every labelled field was short by the label
/// row. These tests pin the estimate to the rows the native `VStack` actually
/// contains.
void main() {
  group('estimateHeight — the field box on its own', () {
    test('a bare single-line field is unchanged at 50', () {
      // Unlabelled fields were never wrong; this is the regression guard.
      expect(LiquidGlassTextFieldMetrics.estimateHeight(), 50);
    });

    test('a multi-line field keeps its per-line growth', () {
      expect(
        LiquidGlassTextFieldMetrics.estimateHeight(maxLines: 4),
        44 + 3 * 24,
      );
    });
  });

  group('estimateHeight — the rows the old estimate ignored', () {
    test('a label adds its line box plus the stack spacing', () {
      expect(
        LiquidGlassTextFieldMetrics.estimateHeight(hasLabel: true),
        50 + 4 + 16,
        reason: 'VStack(spacing: 4) + one .caption line',
      );
    });

    test('a labelled field reserves MORE than an unlabelled one', () {
      // The one property that matters: whatever the exact numbers, a label
      // must never reserve zero, or it bleeds over the header above it.
      expect(
        LiquidGlassTextFieldMetrics.estimateHeight(hasLabel: true),
        greaterThan(LiquidGlassTextFieldMetrics.estimateHeight()),
      );
    });

    test('an oversized label font is honoured, not assumed to be .caption', () {
      expect(
        LiquidGlassTextFieldMetrics.estimateHeight(
          hasLabel: true,
          labelFontSize: 20,
        ),
        50 + 4 + 20 * 1.35,
      );
    });

    test('error text adds a caption row with its top padding', () {
      expect(
        LiquidGlassTextFieldMetrics.estimateHeight(hasErrorText: true),
        50 + 4 + 2 + 16,
      );
    });

    test('counter text adds a caption row too', () {
      expect(
        LiquidGlassTextFieldMetrics.estimateHeight(hasCounterText: true),
        50 + 4 + 2 + 16,
      );
    });

    test('the rows stack rather than replacing one another', () {
      final all = LiquidGlassTextFieldMetrics.estimateHeight(
        hasLabel: true,
        hasErrorText: true,
        hasCounterText: true,
        maxLines: 3,
      );
      expect(all, 44 + 2 * 24 + (4 + 16) + (4 + 2 + 16) * 2);
    });
  });

  group('estimateHeight — the shape the bug needs', () {
    test('every combination reserves at least the field box', () {
      for (final hasLabel in [true, false]) {
        for (final hasError in [true, false]) {
          for (final hasCounter in [true, false]) {
            final estimate = LiquidGlassTextFieldMetrics.estimateHeight(
              hasLabel: hasLabel,
              hasErrorText: hasError,
              hasCounterText: hasCounter,
            );
            expect(
              estimate,
              greaterThanOrEqualTo(
                LiquidGlassTextFieldMetrics.fieldBoxHeight(),
              ),
              reason: 'label=$hasLabel error=$hasError counter=$hasCounter',
            );
          }
        }
      }
    });

    test('adding a row never shrinks the estimate', () {
      // Monotonic in each flag — an estimate that went DOWN when the native
      // stack gained a row is the bleed by another name.
      final base = LiquidGlassTextFieldMetrics.estimateHeight();
      final withLabel = LiquidGlassTextFieldMetrics.estimateHeight(
        hasLabel: true,
      );
      final withBoth = LiquidGlassTextFieldMetrics.estimateHeight(
        hasLabel: true,
        hasErrorText: true,
      );
      expect(withLabel, greaterThan(base));
      expect(withBoth, greaterThan(withLabel));
    });
  });
}
