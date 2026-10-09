import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'liquid_glass_button.dart' show LiquidGlassImagePlacement, LiquidGlassButtonStyle;
import 'shares/liquid_glass_icon.dart';
import 'utils/native_liquid_glass_utils.dart';
import 'utils/liquid_glass_route_suppression.dart';
import 'utils/text_style_utils.dart';

/// Tap gesture claim for the native button-group's `UiKitView`.
///
/// Each button's tap fires `onPressed` on the owning `LiquidGlassButtonData`;
/// declaring the recognizer up-front keeps Flutter's lazy forwarding from
/// buffering/cancelling the touch mid-press (same symptom we saw on the
/// standalone button — glass effect scaled up and never returned).
final Set<Factory<OneSequenceGestureRecognizer>> _buttonGroupGestureRecognizers =
    <Factory<OneSequenceGestureRecognizer>>{
  Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
};

/// Data model for a button inside [LiquidGlassButtonGroup].
///
/// Each button is described by its data—not as a widget—because the group
/// renders all buttons inside a single native platform view to support
/// unified glass effect blending.
class LiquidGlassButtonData {
  /// Button text label. If null, the button is icon-only.
  final String? label;

  /// Icon displayed in the button.
  ///
  /// On iOS, SF Symbols are rendered natively. [IconData] and asset icons are
  /// rasterized to PNG and sent to the native platform view.
  final NativeLiquidGlassIcon? icon;

  /// Callback when the button is pressed.
  final VoidCallback? onPressed;

  /// Whether the button is interactive.
  final bool enabled;

  /// Icon size used by native and fallback rendering.
  final double iconSize;

  /// Optional icon color override.
  final Color? iconColor;

  /// Optional foreground (label text) color.
  final Color? foregroundColor;

  /// Optional text style for the button label.
  ///
  /// Supported properties: [TextStyle.fontSize], [TextStyle.fontWeight],
  /// [TextStyle.fontFamily], and [TextStyle.letterSpacing].
  final TextStyle? labelTextStyle;

  /// Optional glass tint color for this button.
  final Color? tint;

  /// Explicit label text color.
  ///
  /// When provided, overrides [foregroundColor] for the text.
  final Color? labelColor;

  /// Optional badge value displayed on the button.
  ///
  /// When non-null and non-empty, a badge with text is shown.
  /// For a dot badge without text, leave this null and set [showBadge] to true.
  final String? badgeValue;

  /// Whether to show a badge indicator on the button.
  ///
  /// When true without [badgeValue], shows a small dot badge.
  final bool showBadge;

  /// Badge background color. Defaults to red when null.
  final Color? badgeColor;

  /// Badge text color when [badgeValue] is set. Defaults to white when null.
  final Color? badgeTextColor;

  /// Badge size. For text badges, controls font size. For dot badges, controls diameter.
  final double? badgeSize;

  /// Image placement relative to the label text.
  final LiquidGlassImagePlacement imagePlacement;

  /// Spacing between icon and label.
  final double imagePadding;

  /// Optional custom corner radius. When null, uses capsule shape.
  final double? borderRadius;

  /// Optional custom content padding.
  final EdgeInsets? padding;

  /// Optional fixed width.
  final double? width;

  /// Optional fixed height.
  final double? height;

  /// Visual style for this button. Defaults to [LiquidGlassButtonStyle.glass].
  final LiquidGlassButtonStyle style;

  /// Whether native glass effect should be interactive.
  final bool interactive;

  /// Whether the button responds to touch events.
  final bool interaction;

  /// Whether a Flutter popup/modal should keep this button's Liquid Glass
  /// appearance instead of temporarily switching to a standard
  /// `borderedProminent` button style.
  ///
  /// When false (the default), popup suppression keeps the button visible but
  /// disabled and temporarily renders it as a standard prominent button. When
  /// true, popup suppression keeps the Liquid Glass style while still
  /// disabling interaction.
  final bool useLiquidGlassWhenPopupSuppressed;

  /// Maximum number of lines for the label text.
  final int? maxLines;

  /// Optional ID for glass effect union.
  final String? glassEffectUnionId;

  /// Optional ID for glass effect morphing transitions.
  final String? glassEffectId;

  const LiquidGlassButtonData({
    this.label,
    this.icon,
    this.onPressed,
    this.enabled = true,
    this.iconSize = 18,
    this.iconColor,
    this.foregroundColor,
    this.labelTextStyle,
    this.tint,
    this.labelColor,
    this.badgeValue,
    this.showBadge = false,
    this.badgeColor,
    this.badgeTextColor,
    this.badgeSize,
    this.imagePlacement = LiquidGlassImagePlacement.leading,
    this.imagePadding = 8,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
    this.style = LiquidGlassButtonStyle.glass,
    this.interactive = true,
    this.interaction = true,
    this.useLiquidGlassWhenPopupSuppressed = false,
    this.maxLines,
    this.glassEffectUnionId,
    this.glassEffectId,
  });
}

/// A group of buttons rendered together with unified Liquid Glass blending.
///
/// On iOS 26+, all buttons are rendered inside a single native platform view
/// with a shared glass effect union. On other platforms, buttons are rendered
/// as a Flutter [Row] or [Column] of [FilledButton] widgets.
class LiquidGlassButtonGroup extends StatefulWidget {
  /// Button data models.
  final List<LiquidGlassButtonData> buttons;

  /// Layout direction.
  final Axis axis;

  /// Spacing between buttons.
  final double spacing;

  /// Spacing used for glass effect blending (should be > [spacing]).
  final double spacingForGlass;

  const LiquidGlassButtonGroup({super.key, required this.buttons, this.axis = Axis.horizontal, this.spacing = 8.0, this.spacingForGlass = 40.0})
    : assert(buttons.length > 0, 'At least one button is required.');

  @override
  State<LiquidGlassButtonGroup> createState() => _LiquidGlassButtonGroupState();
}

class _LiquidGlassButtonGroupState extends State<LiquidGlassButtonGroup> with LiquidGlassRouteSuppression {
  MethodChannel? _nativeChannel;
  @override MethodChannel? get suppressionChannel => _nativeChannel;
  final Map<int, NativeLiquidGlassIconPayload> _iconPayloads = {};
  int _payloadRequestId = 0;
  bool _payloadsResolved = false;
  int _hotReloadEpoch = 0;
  int _payloadsGeneration = 0;
  /// Natural size of the native buttons, reported by the platform view.
  /// Null until the first native layout.
  Size? _nativeSize;

  /// Version of [_nativeSize]. Native pushes sizes as they change and also
  /// answers `getIntrinsicSize`; the two can arrive out of order, so an older
  /// version is ignored.
  int _nativeSizeVersion = -1;
  int? _lastButtonsHash;
  int _iconSignature = 0;
  Map<String, Object?>? _cachedCreationParams;
  int? _creationParamsCacheKey;

  @override
  void initState() {
    super.initState();
    _iconSignature = _computeIconSignature();
    _preparePayloads();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassButtonGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIconSignature = _computeIconSignature();
    if (newIconSignature != _iconSignature) {
      _iconSignature = newIconSignature;
      _preparePayloads();
    } else {
      _syncPropsToNativeIfNeeded();
    }
  }

  int _computeIconSignature() {
    return Object.hashAll(widget.buttons.map((b) => b.icon?.nativeSignature ?? 0));
  }

  @override
  void reassemble() {
    super.reassemble();
    _iconPayloads.clear();
    clearNativeLiquidGlassIconCaches();
    _preparePayloads();
    if (mounted) {
      setState(() {
        _hotReloadEpoch++;
        _nativeSize = null;
        _nativeSizeVersion = -1;
        _lastButtonsHash = null;
        _cachedCreationParams = null;
        _creationParamsCacheKey = null;
      });
    }
  }

  bool get _needsPayloads {
    return widget.buttons.any((b) => b.icon != null && !b.icon!.isSfSymbol);
  }

  Future<void> _preparePayloads() async {
    final requestId = ++_payloadRequestId;

    if (mounted && _needsPayloads) {
      setState(() {
        _payloadsResolved = false;
      });
    }

    final payloads = await Future.wait(widget.buttons.map((b) => resolveIconPayload(b.icon)));

    if (!mounted || requestId != _payloadRequestId) return;

    for (var i = 0; i < payloads.length; i++) {
      _iconPayloads[i] = payloads[i];
    }

    setState(() {
      _payloadsResolved = true;
      // Bumping the generation invalidates `_computeButtonsHash` and the
      // cached creationParams map in one step — no need to null
      // `_lastButtonsHash` manually.
      _payloadsGeneration++;
    });
    _syncPropsToNativeIfNeeded();
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final ch = _nativeChannel;
    if (ch == null) return;

    final hash = _computeButtonsHash();
    if (_lastButtonsHash != hash) {
      // Native pushes `contentSizeChanged` once the new layout is applied.
      await ch.invokeMethod('updateButtons', _creationParamsCached());
      _lastButtonsHash = hash;
    }
  }

  int _computeButtonsHash() {
    return Object.hash(
      widget.buttons.length,
      widget.axis,
      widget.spacing,
      widget.spacingForGlass,
      Object.hashAll(
        widget.buttons.map(
          (b) => Object.hashAll([
            b.label,
            b.icon?.nativeSignature,
            b.enabled,
            b.iconSize,
            b.iconColor?.toARGB32(),
            b.tint?.toARGB32(),
            b.badgeValue,
            b.showBadge,
            b.badgeColor?.toARGB32(),
            b.badgeTextColor?.toARGB32(),
            b.badgeSize,
            textStyleSignature(b.labelTextStyle),
            b.foregroundColor?.toARGB32(),
            b.labelColor?.toARGB32(),
            b.imagePlacement,
            b.imagePadding,
            b.borderRadius,
            b.padding,
            b.width,
            b.height,
            b.style,
            b.interactive,
            b.interaction,
            b.useLiquidGlassWhenPopupSuppressed,
            b.maxLines,
            b.glassEffectUnionId,
            b.glassEffectId,
          ]),
        ),
      ),
      _hotReloadEpoch,
      _payloadsGeneration,
    );
  }

  Map<String, Object?> _creationParamsCached() {
    final key = _computeButtonsHash();
    final cached = _cachedCreationParams;
    if (_creationParamsCacheKey == key && cached != null) {
      return cached;
    }
    final params = _buildCreationParams();
    _creationParamsCacheKey = key;
    _cachedCreationParams = params;
    return params;
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'contentSizeChanged') {
      _applyNativeSize(call.arguments as Map<Object?, Object?>?);
      return;
    }
    if (call.method == 'onButtonPressed') {
      final index = call.arguments as int?;
      if (index != null && index >= 0 && index < widget.buttons.length) {
        widget.buttons[index].onPressed?.call();
      }
    }
  }

  void _onPlatformViewCreated(int viewId) {
    _nativeChannel?.setMethodCallHandler(null);
    final channel = MethodChannel('liquid-glass-button-group-view/$viewId');
    channel.setMethodCallHandler(_handleNativeMethodCall);
    _nativeChannel = channel;
    // Native just received the cached creationParams; seed `_lastButtonsHash`
    // with the same key so `_syncPropsToNativeIfNeeded` skips a redundant
    // `updateButtons` round-trip in the common case. If props drifted
    // between build and this callback (e.g. a late payload resolved) the
    // hash will differ and we still push the delta.
    _lastButtonsHash = _creationParamsCacheKey;
    _syncPropsToNativeIfNeeded();
    Future.delayed(const Duration(milliseconds: 10), _requestIntrinsicSize);
    syncGlassRouteVisibility();
  }

  @override
  void dispose() {
    _payloadRequestId++;
    _nativeChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _requestIntrinsicSize() async {
    final ch = _nativeChannel;
    if (ch == null || !mounted) return;
    try {
      _applyNativeSize(
        await ch.invokeMethod<Map<Object?, Object?>>('getIntrinsicSize'),
      );
    } catch (_) {}
  }

  void _applyNativeSize(Map<Object?, Object?>? size) {
    final w = (size?['width'] as num?)?.toDouble();
    final h = (size?['height'] as num?)?.toDouble();
    final version = (size?['version'] as num?)?.toInt() ?? 0;
    if (!mounted || w == null || h == null || w <= 0 || h <= 0) return;
    if (version < _nativeSizeVersion) return;
    _nativeSizeVersion = version;
    final next = Size(w, h);
    if (next != _nativeSize) setState(() => _nativeSize = next);
  }

  List<Map<String, Object?>> _buildButtonParams() {
    return List.generate(widget.buttons.length, (i) {
      final b = widget.buttons[i];
      final iconMap = b.icon?.toNativeMap(_iconPayloads[i]) ?? <String, Object?>{};
      final p = b.padding;
      return <String, Object?>{
        'label': b.label,
        ...iconMap,
        'enabled': b.enabled,
        'iconOnly': b.label == null,
        'iconSize': b.iconSize,
        'iconColor': b.iconColor?.toARGB32(),
        'foregroundColor': b.foregroundColor?.toARGB32(),
        'labelStyle': textStylePayload(b.labelTextStyle),
        'tint': b.tint?.toARGB32(),
        'labelColor': b.labelColor?.toARGB32(),
        'badgeValue': b.badgeValue,
        'showBadge': b.showBadge || b.badgeValue != null,
        if (b.badgeColor != null) 'badgeColor': b.badgeColor!.toARGB32(),
        if (b.badgeTextColor != null) 'badgeTextColor': b.badgeTextColor!.toARGB32(),
        if (b.badgeSize != null) 'badgeSize': b.badgeSize,
        'imagePlacement': b.imagePlacement.name,
        'imagePadding': b.imagePadding,
        if (b.borderRadius != null) 'borderRadius': b.borderRadius,
        if (p != null) ...{'paddingTop': p.top, 'paddingBottom': p.bottom, 'paddingLeft': p.left, 'paddingRight': p.right},
        if (b.width != null) 'width': b.width,
        if (b.height != null) 'height': b.height,
        'style': b.style.name,
        'interactive': b.interactive,
        'interaction': b.interaction,
        'useLiquidGlassWhenPopupSuppressed':
            b.useLiquidGlassWhenPopupSuppressed,
        if (b.maxLines != null) 'maxLines': b.maxLines,
        if (b.glassEffectUnionId != null) 'glassEffectUnionId': b.glassEffectUnionId,
        if (b.glassEffectId != null) 'glassEffectId': b.glassEffectId,
      };
    });
  }

  Map<String, Object?> _buildCreationParams() {
    return <String, Object?>{
      'buttons': _buildButtonParams(),
      'axis': widget.axis == Axis.horizontal ? 'horizontal' : 'vertical',
      'spacing': widget.spacing,
      'spacingForGlass': widget.spacingForGlass,
    };
  }

  /// Typical native glass button extent, used until native reports the
  /// group's real size.
  static const double _estimatedButtonExtent = 50;

  Size _estimatedSize() {
    final count = widget.buttons.length;
    final along = count * _estimatedButtonExtent + (count - 1) * widget.spacing;
    return widget.axis == Axis.horizontal
        ? Size(along, _estimatedButtonExtent)
        : Size(_estimatedButtonExtent, along);
  }

  @override
  Widget build(BuildContext context) {
    final payloadReady = !_needsPayloads || _payloadsResolved;

    if (NativeLiquidGlassUtils.usesNativeViews) {
      if (!payloadReady) {
        return const SizedBox.shrink();
      }

      // Sized to the buttons' natural size as laid out natively, so Flutter's
      // layout (Align, Row, Column, ListTile, slivers...) positions the group
      // exactly like any other widget. Until the first native layout reports
      // it, use an estimate rather than expanding to the available width,
      // which would e.g. consume a whole ListTile's trailing slot.
      final size = _nativeSize ?? _estimatedSize();
      return SizedBox(
        width: size.width,
        height: size.height,
        child: UiKitView(
          viewType: 'liquid-glass-button-group-view',
          creationParams: _creationParamsCached(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: _buttonGroupGestureRecognizers,
        ),
      );
    }

    return const SizedBox();
  }
}
