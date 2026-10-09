import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import 'demo_app.dart';
import 'sheets/demo_sheets.dart';

void main() {
  // Used by the Flutter fallback where native sheets aren't available.
  LiquidGlassSheet.registerBuilders(demoSheetBuilders);
  runApp(const LiquidGlassDemoApp());
  // Start a sheet engine after the first frame so the first sheet opens fast.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => LiquidGlassSheet.prewarm(),
  );
}

// ─── BOTTOM SHEET ENTRY POINT ───
// Runs in a separate Flutter engine embedded in a native iOS sheet.
@pragma('vm:entry-point')
void bottomSheetMain(List<String> args) {
  runLiquidGlassSheet(args, builders: demoSheetBuilders);
}
