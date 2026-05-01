import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/native_liquid_glass_utils.dart';

/// Detent sizes for [LiquidGlassSheet].
enum LiquidGlassSheetDetent {
  /// Half height.
  medium,

  /// Full height.
  large,
}

/// Shows a native iOS sheet using UISheetPresentationController with
/// Liquid Glass effects on iOS 26+.
///
/// Uses the shared LiquidGlassPresenter channel for modal presentation.
/// On non-iOS platforms, falls back to [showModalBottomSheet].
class LiquidGlassSheet {
  static const _presenterChannel = MethodChannel('liquid-glass-presenter');
  static int _nextId = 0;

  LiquidGlassSheet._();

  /// Show a sheet with the given parameters.
  ///
  /// Returns a [LiquidGlassSheetHandle] to programmatically dismiss.
  ///
  /// If a Flutter [builder] is provided, the sheet is rendered using
  /// `showModalBottomSheet` so custom Flutter content can control the body.
  ///
  /// If [route] is provided on iOS 26+, the sheet is shown natively using
  /// `UISheetPresentationController` and a hosted `FlutterViewController`.
  static LiquidGlassSheetHandle show({
    required BuildContext context,
    String? title,
    String? message,
    WidgetBuilder? builder,
    String? route,
    List<LiquidGlassSheetDetent> detents = const [
      LiquidGlassSheetDetent.medium,
      LiquidGlassSheetDetent.large,
    ],
    bool prefersGrabberVisible = true,
    bool isModal = false,
  }) {
    final handle = LiquidGlassSheetHandle._();

    final bool useNativeFlutterRoute =
        route != null &&
        builder == null &&
        NativeLiquidGlassUtils.supportsLiquidGlass;
    if (useNativeFlutterRoute) {
      final id = _nextId++;
      handle._sheetId = id;
      final routeWithId = _routeWithSheetId(route, id);

      _presenterChannel.invokeMethod<void>('showFlutterSheet', {
        'id': id,
        'route': routeWithId,
        'title': title,
        'message': message,
        'detents': detents.map((d) => d.name).toList(),
        'prefersGrabberVisible': prefersGrabberVisible,
        'isModal': isModal,
      });

      _presenterChannel.setMethodCallHandler((call) async {
        if (call.method == 'sheetDismissed') {
          final args = call.arguments as Map?;
          if (args != null && args['id'] == id) {
            handle._sheetId = null;
          }
        }
      });

      return handle;
    }

    final bool useFlutterFallback =
        builder != null || !NativeLiquidGlassUtils.supportsLiquidGlass;
    if (useFlutterFallback) {
      handle._isFlutterFallback = true;
      handle._fallbackContext = context;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        enableDrag: !isModal,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black26,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    color: Theme.of(ctx).colorScheme.surface.withOpacity(0.8),
                    child:
                        builder?.call(ctx) ??
                        _buildDefaultBody(ctx, title, message),
                  ),
                ),
              ),
            ),
          );
        },
      ).whenComplete(() {
        handle._fallbackContext = null;
      });

      return handle;
    }

    final id = _nextId++;
    handle._sheetId = id;

    _presenterChannel.invokeMethod<void>('showSheet', {
      'id': id,
      'title': title,
      'message': message,
      'detents': detents.map((d) => d.name).toList(),
      'prefersGrabberVisible': prefersGrabberVisible,
      'isModal': isModal,
    });

    // Listen for dismiss events
    _presenterChannel.setMethodCallHandler((call) async {
      if (call.method == 'sheetDismissed') {
        final args = call.arguments as Map?;
        if (args != null && args['id'] == id) {
          handle._sheetId = null;
        }
      }
    });

    return handle;
  }
}

Widget _buildDefaultBody(BuildContext context, String? title, String? message) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
        ],
        if (message != null) ...[
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}

String _routeWithSheetId(String route, int sheetId) {
  final uri = Uri.parse(route);
  final queryParameters = Map<String, String>.from(uri.queryParameters);
  queryParameters['_sheetId'] = sheetId.toString();
  return uri.replace(queryParameters: queryParameters).toString();
}

/// Handle to dismiss a shown sheet.
class LiquidGlassSheetHandle {
  static const _presenterChannel = MethodChannel('liquid-glass-presenter');
  int? _sheetId;
  BuildContext? _fallbackContext;
  bool _isFlutterFallback = false;

  LiquidGlassSheetHandle._();

  /// Dismiss the sheet.
  Future<void> dismiss() async {
    if (_isFlutterFallback) {
      if (_fallbackContext != null) {
        Navigator.of(_fallbackContext!).maybePop();
        _fallbackContext = null;
      }
      return;
    }

    if (_sheetId != null) {
      await _presenterChannel.invokeMethod<void>('dismissSheet', {
        'id': _sheetId,
      });
      _sheetId = null;
    }
  }
}
