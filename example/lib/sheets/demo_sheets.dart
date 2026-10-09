import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

/// Widgets shown inside [LiquidGlassSheet]s in the demo.
///
/// Shared by `main()` (fallback) and `bottomSheetMain()` (native sheet
/// engine), so they must not depend on state from the main app.
final Map<String, LiquidGlassSheetBuilder> demoSheetBuilders = {
  LanguagePickerSheet.name: (context, arguments) =>
      LanguagePickerSheet(selected: arguments['selected'] as String?),
  DetailsSheet.name: (context, arguments) => DetailsSheet(arguments: arguments),
};

class LanguagePickerSheet extends StatelessWidget {
  static const String name = 'languagePicker';
  static const List<String> languages = [
    'English',
    'Khmer',
    'French',
    'Spanish',
    'Japanese',
  ];

  final String? selected;

  const LanguagePickerSheet({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    final sheet = LiquidGlassSheetScope.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Choose language',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          for (final language in languages)
            ListTile(
              title: Text(language),
              trailing: language == selected
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => sheet.dismiss(language),
            ),
        ],
      ),
    );
  }
}

/// Shows the arguments it was opened with and native Liquid Glass controls,
/// which work inside the sheet's own engine too.
class DetailsSheet extends StatefulWidget {
  static const String name = 'details';

  final Map<String, dynamic> arguments;

  const DetailsSheet({super.key, required this.arguments});

  @override
  State<DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<DetailsSheet> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    final sheet = LiquidGlassSheetScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flutter inside a native sheet', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Opened with: ${widget.arguments}',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Count: $_count', style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                LiquidGlassButton(
                  label: 'Increment',
                  onPressed: () => setState(() => _count++),
                ),
                const SizedBox(width: 12),
                LiquidGlassButton(
                  label: 'Return count',
                  onPressed: () => sheet.dismiss(_count),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
