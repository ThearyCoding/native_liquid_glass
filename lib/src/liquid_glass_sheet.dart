import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/native_liquid_glass_utils.dart';

/// Builds the content of a [LiquidGlassSheet] registered under a name.
typedef LiquidGlassSheetBuilder =
    Widget Function(BuildContext context, Map<String, dynamic> arguments);

/// A resting height of a [LiquidGlassSheet].
class LiquidGlassSheetDetent {
  final String _type;
  final double? _value;

  const LiquidGlassSheetDetent._(this._type, [this._value]);

  /// Roughly half the screen height.
  static const medium = LiquidGlassSheetDetent._('medium');

  /// Full height.
  static const large = LiquidGlassSheetDetent._('large');

  /// A fixed height in logical pixels (iOS 16+, falls back to [medium]).
  const LiquidGlassSheetDetent.height(double height) : this._('height', height);

  /// A fraction (0–1) of the maximum sheet height (iOS 16+, falls back to [medium]).
  const LiquidGlassSheetDetent.fraction(double fraction)
    : this._('fraction', fraction);

  Map<String, Object?> _toMap() => {'type': _type, 'value': _value};
}

/// Shows a native iOS bottom sheet (`UISheetPresentationController`, iOS 15+,
/// with the Liquid Glass background on iOS 26+) whose body is a Flutter widget.
///
/// The widget is rendered by a separate Flutter engine that runs a
/// `@pragma('vm:entry-point')` function in your app — `bottomSheetMain` by
/// default — which must call [runLiquidGlassSheet]:
///
/// ```dart
/// // ─── BOTTOM SHEET ENTRY POINT ───
/// @pragma('vm:entry-point')
/// void bottomSheetMain(List<String> args) {
///   runLiquidGlassSheet(args, builders: bottomSheetBuilders);
/// }
/// ```
///
/// The sheet runs in its own isolate, so it does not share state with the
/// main app: pass data in through `arguments` (JSON-encodable) and send a
/// value back with [LiquidGlassSheetScope.dismiss].
///
/// Below iOS 15 and on other platforms the same builder is shown with
/// [showModalBottomSheet]; call [registerBuilders] in `main()` for that.
class LiquidGlassSheet {
  static const _presenterChannel = MethodChannel('liquid-glass-presenter');
  static final Map<String, LiquidGlassSheetBuilder> _builders = {};
  static int _nextId = 0;

  LiquidGlassSheet._();

  /// Starts a sheet engine ahead of time so the next [show] opens without
  /// waiting for engine startup. Call it once after your first frame; after
  /// that a spare engine is kept ready automatically after each sheet.
  ///
  /// [entrypoint] and [libraryUri] must match the ones passed to [show].
  /// Keeping a spare engine costs some memory while the app runs.
  static Future<void> prewarm({
    String entrypoint = 'bottomSheetMain',
    String? libraryUri,
  }) async {
    if (!NativeLiquidGlassUtils.supportsNativeSheet) return;
    await _presenterChannel.invokeMethod<void>('prewarmSheet', {
      'entrypoint': entrypoint,
      'libraryUri': libraryUri,
    });
  }

  /// Registers builders in the main isolate, used by the non-native fallback.
  static void registerBuilders(Map<String, LiquidGlassSheetBuilder> builders) {
    _builders.addAll(builders);
  }

  /// Shows the sheet registered under [name].
  ///
  /// The returned handle's [LiquidGlassSheetHandle.result] completes when
  /// the sheet is dismissed, with the value passed to `dismiss` (or `null` if
  /// the user swiped it away). [T] must be a type the standard message codec
  /// supports (String, num, bool, List, Map).
  static LiquidGlassSheetHandle<T> show<T>({
    required BuildContext context,
    required String name,
    Map<String, dynamic> arguments = const {},
    List<LiquidGlassSheetDetent> detents = const [
      LiquidGlassSheetDetent.medium,
      LiquidGlassSheetDetent.large,
    ],
    bool prefersGrabberVisible = true,
    bool isModal = false,
    double? cornerRadius,
    String entrypoint = 'bottomSheetMain',
    String? libraryUri,
  }) {
    if (!NativeLiquidGlassUtils.supportsNativeSheet) {
      return _showFallback<T>(context, name, arguments, isModal);
    }

    final id = _nextId++;
    final handle = LiquidGlassSheetHandle<T>._native(id);
    _presenterChannel
        .invokeMethod<Object?>('showSheet', {
          'id': id,
          'name': name,
          'arguments': jsonEncode(arguments),
          'entrypoint': entrypoint,
          'libraryUri': libraryUri,
          'detents': detents.map((d) => d._toMap()).toList(),
          'prefersGrabberVisible': prefersGrabberVisible,
          'isModal': isModal,
          'cornerRadius': cornerRadius,
        })
        .then(
          (value) => handle._complete(value as T?),
          onError: handle._completer.completeError,
        );
    return handle;
  }

  static LiquidGlassSheetHandle<T> _showFallback<T>(
    BuildContext context,
    String name,
    Map<String, dynamic> arguments,
    bool isModal,
  ) {
    final builder = _builders[name];
    final handle = LiquidGlassSheetHandle<T>._fallback();
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: !isModal,
      enableDrag: !isModal,
      showDragHandle: true,
      builder: (sheetContext) {
        handle._fallbackContext = sheetContext;
        return LiquidGlassSheetScope(
          arguments: arguments,
          onDismiss: (result) => Navigator.of(sheetContext).pop(result as T?),
          child: builder != null
              ? Builder(builder: (ctx) => builder(ctx, arguments))
              : _UnknownSheet(name: name),
        );
      },
    ).then(handle._complete, onError: handle._completer.completeError);
    return handle;
  }
}

/// Handle to a sheet shown with [LiquidGlassSheet.show].
class LiquidGlassSheetHandle<T> {
  static const _presenterChannel = MethodChannel('liquid-glass-presenter');

  final int? _id;
  final Completer<T?> _completer = Completer<T?>();
  BuildContext? _fallbackContext;

  LiquidGlassSheetHandle._native(int id) : _id = id;
  LiquidGlassSheetHandle._fallback() : _id = null;

  /// Completes with the dismissal value when the sheet closes.
  Future<T?> get result => _completer.future;

  /// Whether the sheet is still on screen.
  bool get isShowing => !_completer.isCompleted;

  /// Dismisses the sheet from the main app, completing [result] with [value].
  Future<void> dismiss([T? value]) async {
    if (!isShowing) return;
    if (_id != null) {
      await _presenterChannel.invokeMethod<void>('dismissSheet', {
        'id': _id,
        'result': value,
      });
      return;
    }
    final ctx = _fallbackContext;
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx).pop(value);
    }
  }

  void _complete(T? value) {
    _fallbackContext = null;
    if (!_completer.isCompleted) _completer.complete(value);
  }
}

/// Exposes the sheet's arguments and a way to dismiss it to the sheet content.
///
/// Available above every widget built by a [LiquidGlassSheetBuilder],
/// both in the native sheet engine and in the non-native fallback.
class LiquidGlassSheetScope extends InheritedWidget {
  /// The arguments passed to [LiquidGlassSheet.show].
  final Map<String, dynamic> arguments;
  final ValueChanged<Object?> _onDismiss;

  const LiquidGlassSheetScope({
    super.key,
    required this.arguments,
    required ValueChanged<Object?> onDismiss,
    required super.child,
  }) : _onDismiss = onDismiss;

  /// Closes the sheet and completes the caller's `result` with [result].
  void dismiss([Object? result]) => _onDismiss(result);

  static LiquidGlassSheetScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidGlassSheetScope>();

  static LiquidGlassSheetScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No LiquidGlassSheetScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(LiquidGlassSheetScope oldWidget) =>
      arguments != oldWidget.arguments;
}

/// Entry point argument the native side passes to a prewarmed engine.
const _prewarmArgument = '__liquid_glass_prewarm__';
const _contentChannel = MethodChannel('liquid-glass-sheet-content');

/// Runs the bottom sheet app. Call it from your `@pragma('vm:entry-point')`
/// bottom sheet entry point, forwarding the entry point's `args`.
void runLiquidGlassSheet(
  List<String> args, {
  required Map<String, LiquidGlassSheetBuilder> builders,
  ThemeData? theme,
  ThemeData? darkTheme,
}) {
  WidgetsFlutterBinding.ensureInitialized();

  void run(String name, String argumentsJson) {
    final arguments = Map<String, dynamic>.from(
      jsonDecode(argumentsJson) as Map,
    );
    final builder = builders[name];
    runApp(
      _sheetApp(
        arguments: arguments,
        theme: theme,
        darkTheme: darkTheme,
        child: builder != null
            ? Builder(builder: (ctx) => builder(ctx, arguments))
            : _UnknownSheet(name: name),
      ),
    );
    // The isolate is up and the widget tree is attached: the native side can
    // present the sheet now without it sliding up empty.
    _contentChannel.invokeMethod<void>('ready');
  }

  // Prewarmed engine: wait until the native side says which sheet to show,
  // and tell it this isolate is up and listening.
  if (args.isNotEmpty && args.first == _prewarmArgument) {
    _contentChannel.setMethodCallHandler((call) async {
      if (call.method != 'configure') return;
      _contentChannel.setMethodCallHandler(null);
      final config = call.arguments as Map;
      run(config['name'] as String, config['arguments'] as String);
    });
    _contentChannel.invokeMethod<void>('warm');
    return;
  }

  run(args.length > 1 ? args[1] : '', args.length > 2 ? args[2] : '{}');
}

Widget _sheetApp({
  required Map<String, dynamic> arguments,
  required Widget child,
  ThemeData? theme,
  ThemeData? darkTheme,
}) {
  ThemeData transparent(ThemeData data) => data.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
  );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    color: Colors.transparent,
    theme: transparent(theme ?? ThemeData(brightness: Brightness.light)),
    darkTheme: transparent(darkTheme ?? ThemeData(brightness: Brightness.dark)),
    home: LiquidGlassSheetScope(
      arguments: arguments,
      onDismiss: (result) =>
          _contentChannel.invokeMethod<void>('dismiss', {'result': result}),
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}

class _UnknownSheet extends StatelessWidget {
  final String name;

  const _UnknownSheet({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('No bottom sheet registered for "$name"'));
  }
}
