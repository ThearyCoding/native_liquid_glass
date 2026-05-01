import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../widgets/theme_mode_action_button.dart';

class LiquidGlassSheetPreviewPage extends StatefulWidget {
  static const String flutterSheetRoute = '/flutter-sheet';

  final ValueChanged<bool> onThemeChanged;

  const LiquidGlassSheetPreviewPage({super.key, required this.onThemeChanged});

  @override
  State<LiquidGlassSheetPreviewPage> createState() =>
      _LiquidGlassSheetPreviewPageState();
}

class _LiquidGlassSheetPreviewPageState
    extends State<LiquidGlassSheetPreviewPage> {
  LiquidGlassSheetHandle? _activeHandle;
  bool _showTitle = true;
  bool _showMessage = true;
  bool _prefersGrabberVisible = true;
  bool _isModal = false;
  bool _mediumDetent = true;
  bool _largeDetent = true;

  List<LiquidGlassSheetDetent> get _detents => [
    if (_mediumDetent) LiquidGlassSheetDetent.medium,
    if (_largeDetent) LiquidGlassSheetDetent.large,
  ];

  void _showBuilderSheet(BuildContext context) {
    _activeHandle?.dismiss();
    _activeHandle = LiquidGlassSheet.show(
      context: context,
      title: _showTitle ? 'Sheet Title' : null,
      message: _showMessage
          ? 'This is a Liquid Glass native sheet on iOS 26+.'
          : null,
      detents: _detents.isNotEmpty ? _detents : [LiquidGlassSheetDetent.medium],
      prefersGrabberVisible: _prefersGrabberVisible,
      isModal: _isModal,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Custom sheet body content. Can include any widget.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _activeHandle?.dismiss();
                _activeHandle = null;
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteSheet(BuildContext context) {
    _activeHandle?.dismiss();
    _activeHandle = LiquidGlassSheet.show(
      context: context,
      route: LiquidGlassSheetPreviewPage.flutterSheetRoute,
      detents: _detents.isNotEmpty ? _detents : [LiquidGlassSheetDetent.medium],
      prefersGrabberVisible: _prefersGrabberVisible,
      isModal: _isModal,
    );
  }

  @override
  void dispose() {
    _activeHandle?.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LiquidGlassSheet preview'),
        actions: [ThemeModeActionButton(onThemeChanged: widget.onThemeChanged)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showBuilderSheet(context),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Show builder sheet'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _showRouteSheet(context),
                        icon: const Icon(Icons.route_rounded),
                        label: const Text('Show route sheet'),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show title'),
                        value: _showTitle,
                        onChanged: (v) => setState(() => _showTitle = v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show message'),
                        value: _showMessage,
                        onChanged: (v) => setState(() => _showMessage = v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Prefers grabber visible'),
                        value: _prefersGrabberVisible,
                        onChanged: (v) =>
                            setState(() => _prefersGrabberVisible = v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Modal (non-dismissible)'),
                        value: _isModal,
                        onChanged: (v) => setState(() => _isModal = v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Medium detent'),
                        value: _mediumDetent,
                        onChanged: (v) => setState(() => _mediumDetent = v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Large detent'),
                        value: _largeDetent,
                        onChanged: (v) => setState(() => _largeDetent = v),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlutterSheetRoutePage extends StatefulWidget {
  const FlutterSheetRoutePage({super.key});

  @override
  State<FlutterSheetRoutePage> createState() => _FlutterSheetRoutePageState();
}

class _FlutterSheetRoutePageState extends State<FlutterSheetRoutePage> {
  static const _presenterChannel = MethodChannel('liquid-glass-presenter');
  String _selectedLanguage = 'English';

  int? get _sheetId {
    final idFromGet = Get.parameters['_sheetId'];
    if (idFromGet != null) {
      return int.tryParse(idFromGet);
    }

    final routeName = ModalRoute.of(context)?.settings.name;
    if (routeName == null) {
      return null;
    }
    return int.tryParse(Uri.parse(routeName).queryParameters['_sheetId'] ?? '');
  }

  Future<void> _closeSheet() async {

    final sheetId = _sheetId;

    print('Closing sheet with id: $sheetId');
    if (sheetId != null) {
   await _presenterChannel.invokeMethod<void>('dismissSheet', {
        'id': _sheetId,
      });
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Language selection',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose your preferred language for this sheet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: _selectedLanguage,
                items: const [
                  DropdownMenuItem(value: 'English', child: Text('English')),
                  DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
                  DropdownMenuItem(value: 'French', child: Text('French')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'This is normal content inside the native Flutter sheet. It does not use a Scaffold.',
              ),
              const SizedBox(height: 24),
              LiquidGlassButton(
                onPressed: _closeSheet,
                label: 'Close sheet'
              ),
            ],
          ),
        ),
      ),
    );
  }
}
