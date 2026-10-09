import 'package:flutter/foundation.dart';

import '../platform/platform_info_stub.dart' if (dart.library.io) '../platform/platform_info_io.dart' as platform_info;

/// Utility helpers for checking native Liquid Glass availability.
final class NativeLiquidGlassUtils {
  NativeLiquidGlassUtils._();

  static int? _cachedIOSVersion;
  static bool _isInitialized = false;

  static void _ensureInitialized() {
    if (_isInitialized) return;
    if (!kIsWeb && platform_info.isIOS) {
      _cachedIOSVersion = _parseMajorVersion(platform_info.operatingSystemVersion);
    }
    _isInitialized = true;
  }

  static int? _parseMajorVersion(String osVersion) {
    final match = RegExp(r'(\d+)').firstMatch(osVersion);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// The cached iOS major version. `null` on non-iOS or web.
  static int? get iosVersion {
    _ensureInitialized();
    return _cachedIOSVersion;
  }

  /// Returns `true` on iOS 26+. The only platform where Liquid Glass is
  /// currently supported.
  static bool get supportsLiquidGlass {
    if (debugSupportsLiquidGlassOverride != null) {
      return debugSupportsLiquidGlassOverride!;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    _ensureInitialized();
    return (_cachedIOSVersion ?? 0) >= 26;
  }

  /// Overrides [supportsLiquidGlass] in tests. Set back to `null` in tearDown.
  @visibleForTesting
  static bool? debugSupportsLiquidGlassOverride;

  /// Minimum iOS version for the native (UIKit / SwiftUI) components.
  static const int minimumNativeIOSVersion = 16;

  /// Returns `true` on iOS 16+, where the components render natively.
  ///
  /// On iOS 26+ they use Liquid Glass; on iOS 16–25 they use the plain
  /// system style (standard UIKit / SwiftUI controls, no glass). Elsewhere
  /// the Flutter fallbacks are used.
  static bool get usesNativeViews {
    if (debugUsesNativeViewsOverride != null) {
      return debugUsesNativeViewsOverride!;
    }
    if (debugSupportsLiquidGlassOverride != null) {
      return debugSupportsLiquidGlassOverride!;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    _ensureInitialized();
    return (_cachedIOSVersion ?? 0) >= minimumNativeIOSVersion;
  }

  /// Overrides [usesNativeViews] in tests. Set back to `null` in tearDown.
  @visibleForTesting
  static bool? debugUsesNativeViewsOverride;

  /// Returns `true` on iOS 15+, where native sheets with detents
  /// (`UISheetPresentationController`) are available. They get the Liquid
  /// Glass background on iOS 26+ and the system background below that.
  static bool get supportsNativeSheet {
    if (debugSupportsNativeSheetOverride != null) {
      return debugSupportsNativeSheetOverride!;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    _ensureInitialized();
    return (_cachedIOSVersion ?? 0) >= 15;
  }

  /// Overrides [supportsNativeSheet] in tests. Set back to `null` in tearDown.
  @visibleForTesting
  static bool? debugSupportsNativeSheetOverride;

  /// Forces a reset of the cached version. Only needed for testing.
  @visibleForTesting
  static void reset() {
    _cachedIOSVersion = null;
    _isInitialized = false;
  }
}
