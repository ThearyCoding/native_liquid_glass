import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

class ThemeModeActionButton extends StatelessWidget {
  final ValueChanged<bool> onThemeChanged;
final String? glassEffectUnionId;
final String? glassEffectId;
  const ThemeModeActionButton({super.key, required this.onThemeChanged, this.glassEffectUnionId, this.glassEffectId});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlassButton.icon(
      glassEffectUnionId: glassEffectUnionId,
      glassEffectId: glassEffectId,
      useLiquidGlassWhenPopupSuppressed: true,
      tooltip: isDarkTheme ? 'Switch to light theme' : 'Switch to dark theme',
      icon: NativeLiquidGlassIcon.sfSymbol(isDarkTheme ? 'sun.max' : 'moon'),
      onPressed: () => onThemeChanged(!isDarkTheme),
    );
  }
}
