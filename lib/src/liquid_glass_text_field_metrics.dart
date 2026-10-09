import 'package:flutter/foundation.dart';

/// How tall a box Flutter must reserve for a native [LiquidGlassTextField]
/// *before* the native side has measured itself and reported back.
///
/// ## Why an under-estimate is the dangerous direction
///
/// The native view is a `VStack(alignment: .leading, spacing: 4)` of
/// label / field / errorText / counterText — see
/// `LiquidGlassTextFieldView.body` — and its host container sets
/// `clipsToBounds = false` (`LiquidGlassTextFieldPlatformView`). A Flutter box
/// that is too SHORT therefore does not crop the native view. It lets the
/// label and the caption rows paint over whatever Flutter laid out above and
/// below, which is the overlap in
/// `ai_review/Screen Recording 2026-09-22 at 2.28.40 PM.mov`: a section header
/// sitting on top of the next field's label.
///
/// Being too TALL is mild by comparison — `onSizeChanged` replaces this with
/// the measured height a frame or two later and the extra gap closes. So every
/// row the native stack can contain is counted here, and each number is meant
/// as an upper bound rather than a best guess.
///
/// ## Why it is hit more than once
///
/// The estimate is not just a first-frame concern. A field inside a lazy
/// `ListView` is disposed when it scrolls past the cache extent and rebuilt
/// with a fresh `State` when it comes back, so the measured height is gone and
/// this estimate is in force again — which is why the overlap shows up
/// "sometimes" rather than once at startup.
@immutable
class LiquidGlassTextFieldMetrics {
  const LiquidGlassTextFieldMetrics._();

  /// `VStack(alignment: .leading, spacing: 4)` in `LiquidGlassTextFieldView`.
  static const double stackSpacing = 4;

  /// One line of SwiftUI `.caption`, the default font for the label, the
  /// error text and the counter text alike (`labelFont`, and the `.caption`
  /// literals on the caption rows).
  static const double captionLineHeight = 16;

  /// `.padding(.top, 2)` carried by the errorText and counterText rows.
  static const double captionTopPadding = 2;

  /// Ratio from a font's point size to the line box it occupies. Only used
  /// when a caller overrides the label font through `labelStyle.fontSize`.
  static const double lineHeightFactor = 1.35;

  /// A single-line field box on its own. Unchanged from the value this
  /// estimate has always used, so an unlabelled field reserves exactly what it
  /// reserved before.
  static const double singleLineFieldHeight = 50;

  /// Per-line growth of the multi-line editor — `maxLines * 24` is
  /// `textEditorMaxHeight` in `LiquidGlassTextFieldView`.
  static const double multilineLineHeight = 24;

  /// Base of the multi-line estimate, also unchanged.
  static const double multilineBaseHeight = 44;

  /// The height of the field box alone, with no label or caption rows.
  static double fieldBoxHeight({int? maxLines}) {
    if (maxLines != null && maxLines > 1) {
      return multilineBaseHeight + (maxLines - 1) * multilineLineHeight;
    }
    return singleLineFieldHeight;
  }

  /// One caption row: the `.caption` line, its top padding, and the stack
  /// spacing that separates it from the row above.
  static const double captionRowHeight =
      stackSpacing + captionTopPadding + captionLineHeight;

  /// The estimate itself: the field box plus every row the native `VStack`
  /// stacks around it.
  ///
  /// [labelFontSize] is `labelStyle?.fontSize`; null means the native default
  /// `.caption`. [fieldHeight] replaces the field box estimate.
  static double estimateHeight({
    bool hasLabel = false,
    double? labelFontSize,
    bool hasErrorText = false,
    bool hasCounterText = false,
    int? maxLines,
    double? fieldHeight,
  }) {
    var height = fieldHeight ?? fieldBoxHeight(maxLines: maxLines);

    if (hasLabel) {
      // The label row has no `.padding(.top,)` of its own, only the spacing
      // between it and the field.
      final lineHeight = labelFontSize == null
          ? captionLineHeight
          : labelFontSize * lineHeightFactor;
      height += stackSpacing + lineHeight;
    }
    if (hasErrorText) height += captionRowHeight;
    if (hasCounterText) height += captionRowHeight;

    return height;
  }
}
