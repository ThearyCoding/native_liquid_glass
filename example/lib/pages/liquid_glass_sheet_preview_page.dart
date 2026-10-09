import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../sheets/demo_sheets.dart';
import '../widgets/theme_mode_action_button.dart';

class LiquidGlassSheetPreviewPage extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;

  const LiquidGlassSheetPreviewPage({super.key, required this.onThemeChanged});

  @override
  State<LiquidGlassSheetPreviewPage> createState() =>
      _LiquidGlassSheetPreviewPageState();
}

class _LiquidGlassSheetPreviewPageState
    extends State<LiquidGlassSheetPreviewPage> {
  LiquidGlassSheetHandle<Object>? _activeHandle;
  String _language = 'English';
  String _lastResult = '—';
  bool _mediumDetent = true;
  bool _largeDetent = true;
  bool _customHeightDetent = false;
  bool _prefersGrabberVisible = true;
  bool _isModal = false;
  bool _roundedCorners = false;

  List<LiquidGlassSheetDetent> get _detents {
    final detents = [
      if (_customHeightDetent) const LiquidGlassSheetDetent.height(320),
      if (_mediumDetent) LiquidGlassSheetDetent.medium,
      if (_largeDetent) LiquidGlassSheetDetent.large,
    ];
    return detents.isEmpty ? [LiquidGlassSheetDetent.medium] : detents;
  }

  /// Opens a sheet (closing the current one first) and returns its handle.
  Future<LiquidGlassSheetHandle<Object>?> _show(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    await _activeHandle?.dismiss();
    if (!mounted) return null;
    final handle = LiquidGlassSheet.show<Object>(
      context: context,
      name: name,
      arguments: arguments,
      detents: _detents,
      prefersGrabberVisible: _prefersGrabberVisible,
      isModal: _isModal,
      cornerRadius: _roundedCorners ? 40 : null,
    );
    _activeHandle = handle;
    handle.result.then(
      (result) {
        if (identical(_activeHandle, handle)) _activeHandle = null;
        if (!mounted) return;
        setState(() {
          _lastResult = '$result';
          if (name == LanguagePickerSheet.name && result is String) {
            _language = result;
          }
        });
      },
      onError: (Object error) {
        if (identical(_activeHandle, handle)) _activeHandle = null;
        if (mounted) setState(() => _lastResult = 'error: $error');
      },
    );
    return handle;
  }

  Future<void> _showThenDismissFromHost() async {
    final handle = await _show(DetailsSheet.name, {'closesIn': '3s'});
    await Future<void>.delayed(const Duration(seconds: 3));
    // Close only the sheet this button opened, and only if it's still open;
    // never a sheet the user opened afterwards.
    if (handle != null && handle.isShowing) {
      await handle.dismiss('auto-closed after 3s');
    }
  }

  @override
  void dispose() {
    _activeHandle?.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nativeSheet = NativeLiquidGlassUtils.supportsNativeSheet;
    return Scaffold(
      appBar: AppBar(
        title: const Text('LiquidGlassSheet preview'),
        actions: [ThemeModeActionButton(onThemeChanged: widget.onThemeChanged)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            nativeSheet
                ? 'Native UISheetPresentationController with Flutter content'
                : 'Flutter fallback (native sheet needs iOS 15+)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                _show(LanguagePickerSheet.name, {'selected': _language}),
            icon: const Icon(Icons.language_rounded),
            label: Text('Language picker ($_language)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _show(DetailsSheet.name, {
              'from': 'preview page',
              'openedAt': TimeOfDay.now().format(context),
            }),
            icon: const Icon(Icons.widgets_rounded),
            label: const Text('Interactive sheet'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showThenDismissFromHost,
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Auto-close after 3s (demo)'),
          ),
          const SizedBox(height: 12),
          Text('Last result: $_lastResult'),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _option(
                    'Medium detent',
                    _mediumDetent,
                    (v) => _mediumDetent = v,
                  ),
                  _option(
                    'Large detent',
                    _largeDetent,
                    (v) => _largeDetent = v,
                  ),
                  _option(
                    'Custom 320pt detent (iOS 16+)',
                    _customHeightDetent,
                    (v) => _customHeightDetent = v,
                  ),
                  _option(
                    'Prefers grabber visible',
                    _prefersGrabberVisible,
                    (v) => _prefersGrabberVisible = v,
                  ),
                  _option(
                    'Modal (non-dismissible)',
                    _isModal,
                    (v) => _isModal = v,
                  ),
                  _option(
                    'Corner radius 40',
                    _roundedCorners,
                    (v) => _roundedCorners = v,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(String title, bool value, ValueSetter<bool> update) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: (v) => setState(() => update(v)),
    );
  }
}
