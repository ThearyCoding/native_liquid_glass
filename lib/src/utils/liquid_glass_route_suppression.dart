import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../liquid_glass_lifecycle.dart';
import 'native_liquid_glass_utils.dart';

/// Approximates the drop shadow of native Liquid Glass (iOS 26). Drawn by
/// Flutter while a modal covers the native view, so the modal barrier dims it
/// like the rest of the page.
const List<BoxShadow> kLiquidGlassCoveredShadow = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 6)),
];

/// Mixin that handles both:
/// 1. Hides the native liquid glass during page navigation (when pushing/popping routes)
/// 2. Disables (not hides) the native component when modals/popups are open
mixin LiquidGlassRouteSuppression<T extends StatefulWidget> on State<T> {
  /// The per-view method channel used to send `setSuppressed` to native.
  MethodChannel? get suppressionChannel;
  
  /// Override this to force the tab bar to always show regardless of route state.
  /// When true, the tab bar will ignore all suppression attempts.
  @protected
  bool get forceShow => false;
  
  @protected
  bool get isGlassRouteSuppressed => !_shouldBeInteractive;

  bool _shouldRender = true;
  bool _shouldBeInteractive = true;
  bool _isMounted = false;
  bool _lastModalState = false;

  /// While a Flutter modal covers the native view, the view is clipped to
  /// its shape (the glass shadow would otherwise paint over the modal
  /// barrier), so Flutter draws the shadow behind it instead, in [shape].
  /// No shadow at other times, or when [shape] is null (a style without
  /// glass).
  @protected
  Widget withGlassShadowWhileCovered(Widget child, ShapeBorder? shape) {
    final covered = !forceShow && _shouldRender && !_shouldBeInteractive;
    final showShadow =
        shape != null && covered && NativeLiquidGlassUtils.supportsLiquidGlass;
    // Always the same wrapper, only the decoration changes: inserting or
    // removing a widget above the platform view recreates the native view.
    return DecoratedBox(
      decoration: showShadow
          ? ShapeDecoration(shape: shape, shadows: kLiquidGlassCoveredShadow)
          : const BoxDecoration(),
      child: child,
    );
  }

  @protected
  Widget wrapWithGlassRouteSuppression(Widget child) {
    // If forceShow is true, always return the child without wrapping
    if (forceShow) {
      return child;
    }
    
    if (!_shouldRender) {
      // Hide while another route is on top, but keep the exact layout slot and
      // the native view alive. Collapsing to zero size made neighbours (e.g.
      // other AppBar actions) jump during route transitions, and removing the
      // platform view recreated and re-measured it on every return.
      return Visibility.maintain(
        visible: false,
        child: child,
      );
    }

    return IgnorePointer(
      ignoring: !_shouldBeInteractive,
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    
    // Always check visibility, forceShow just changes behavior
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _checkVisibility();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isMounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isMounted) {
          _checkVisibility();
        }
      });
    }
  }
  
  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMounted) {
      _checkVisibility();
    }
  }

  void _checkVisibility() {
    if (!_isMounted) return;
    
    final route = ModalRoute.of(context);
    if (route == null) return;

    final bool isCurrentRoute = route.isCurrent;
    final bool hasModal = LiquidGlassPopupRouteTracker.hasActivePopupRoute;
    final bool isNavigatingAway = !isCurrentRoute && !hasModal;
    
    // Force show overrides everything
    if (forceShow) {
      if (!_shouldRender || !_shouldBeInteractive) {
        _shouldRender = true;
        _shouldBeInteractive = true;
        if (_isMounted) setState(() {});
      }
      // Still need to send suppression false to native so button is enabled
      if (_lastModalState != false) {
        _sendSuppressionToNative(false, 'force-show');
        _lastModalState = false;
      }
      return;
    }
    
    if (isNavigatingAway) {
      if (_shouldRender != false) {
        _setRenderState(false);
      }
    } else if (hasModal) {
      if (_shouldRender != true) _setRenderState(true);
      if (_shouldBeInteractive != false) _setInteractiveState(false);
    } else if (isCurrentRoute) {
      if (_shouldRender != true) _setRenderState(true);
      if (_shouldBeInteractive != true) _setInteractiveState(true);
    }
  }

  void _setRenderState(bool shouldRender) {
    if (_shouldRender == shouldRender) return;
    
    _shouldRender = shouldRender;
    
    if (!shouldRender && !forceShow) {
      _sendSuppressionToNative(true, 'navigation');
    } else if (_shouldBeInteractive && !forceShow) {
      _sendSuppressionToNative(false, 'route');
    }
    
    if (_isMounted) {
      setState(() {});
    }
  }

  void _setInteractiveState(bool shouldBeInteractive) {
    if (_shouldBeInteractive == shouldBeInteractive) return;
    
    _shouldBeInteractive = shouldBeInteractive;
    
    if (!forceShow) {
      _sendSuppressionToNative(!shouldBeInteractive, 'popup');
      _lastModalState = !shouldBeInteractive;
    }
    
    if (_isMounted) {
      setState(() {});
    }
  }

  void _sendSuppressionToNative(bool suppress, String reason) {
    final ch = suppressionChannel;
    if (ch == null) return;

    try {
      debugPrint('LiquidGlassButton: Sending suppression - suppress=$suppress, reason=$reason, forceShow=$forceShow');
      ch.invokeMethod('setSuppressed', {
        'suppressed': suppress,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('LiquidGlassButton: Error sending suppression: $e');
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  /// Call when the native view is (re)created. A new native view starts out
  /// unsuppressed, and [_checkVisibility] only sends changes, so the current
  /// suppression is sent again here; otherwise a view recreated under a modal
  /// would stay interactive.
  void syncGlassRouteVisibility() {
    if (!_isMounted) return;
    _checkVisibility();
    if (forceShow) return;
    if (!_shouldRender) {
      _sendSuppressionToNative(true, 'navigation');
    } else if (!_shouldBeInteractive) {
      _sendSuppressionToNative(true, 'popup');
    }
  }
}