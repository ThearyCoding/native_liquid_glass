import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'utils/text_style_utils.dart';
import 'liquid_glass_text_field_metrics.dart';

/// Text input type for the native text field.
enum LiquidGlassTextFieldType {
  text,
  multiline,
  email,
  password,
  number,
  phone,
  url,

  /// One-time code: number pad, digits only, SMS / Mail code autofill, and
  /// [LiquidGlassTextField.maxLength] (the number of digits) defaults to 6.
  /// See also [LiquidGlassTextField.otpStyle] and
  /// [LiquidGlassTextField.onCompleted].
  otp,
}

/// How a [LiquidGlassTextFieldType.otp] field is drawn.
enum LiquidGlassOtpStyle {
  /// A regular text field.
  field,

  /// One box per digit, drawn in the field's [LiquidGlassTextField.style]:
  /// [LiquidGlassTextFieldStyle.glass] gives Liquid Glass boxes,
  /// [LiquidGlassTextFieldStyle.rounded] filled boxes,
  /// [LiquidGlassTextFieldStyle.plain] outlined boxes, and
  /// [LiquidGlassTextFieldStyle.underlined] a line under each digit.
  ///
  /// The boxes stretch to fill the field's width edge to edge with equal
  /// spacing, so the row is always centered; give the field a
  /// [LiquidGlassTextField.width] for a narrower row.
  ///
  /// [LiquidGlassTextField.errorText] turns the boxes red and shakes them;
  /// [LiquidGlassTextField.obscureText] shows dots;
  /// [LiquidGlassTextField.cursorColor] (or tint) colors the active box.
  boxes,
}

/// Magnifier style for text selection (iOS only)
enum LiquidGlassMagnifierStyle { standard, glass, minimal, elevated, compact }

/// Visual style for [LiquidGlassTextField].
enum LiquidGlassTextFieldStyle { plain, rounded, glass, underlined }

/// A native-styled Liquid Glass text field for iOS.
///
/// Mirrors the property surface of Flutter's built-in [TextField] widget
/// ([controller], [focusNode], [onSubmitted], [onEditingComplete],
/// [textAlign], [textCapitalization], [autocorrect], [enableSuggestions],
/// [cursorColor]) so it can be used as a drop-in, natively-rendered
/// replacement.
class LiquidGlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? text;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final String? hint;
  final String? label;
  final String? errorText;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final LiquidGlassTextFieldType textFieldType;
  final LiquidGlassTextFieldStyle style;
  final double? width;
  final LiquidGlassMagnifierStyle? magnifierStyle;
  final double? height;
  final double? borderRadius;
  final EdgeInsets? padding;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final TextStyle? labelStyle;
  final TextStyle? errorStyle;
  final Color? foregroundColor;
  final Color? cursorColor;
  final Color? tint;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final String? glassEffectUnionId;
  final String? glassEffectId;
  final LiquidGlassBorder? border;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final String? semanticLabel;
  final String? counterText;
  final int? maxLength;
  final NativeLiquidGlassIcon? prefixIcon;
  final NativeLiquidGlassIcon? suffixIcon;
  final Color? prefixIconColor;
  final Color? suffixIconColor;
  final VoidCallback? onPrefixIconTap;
  final VoidCallback? onSuffixIconTap;

  /// Space kept free around the field when it is scrolled into view above the
  /// keyboard, like [TextField.scrollPadding].
  final EdgeInsets scrollPadding;

  /// Called once each time the text reaches [maxLength] characters, e.g. when
  /// a one-time code is complete.
  final ValueChanged<String>? onCompleted;

  /// How a [LiquidGlassTextFieldType.otp] field is drawn: one text field, or
  /// one glass box per digit.
  final LiquidGlassOtpStyle otpStyle;

  const LiquidGlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.text,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.hint,
    this.label,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.textFieldType = LiquidGlassTextFieldType.text,
    this.style = LiquidGlassTextFieldStyle.glass,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
    this.textStyle,
    this.hintStyle,
    this.labelStyle,
    this.errorStyle,
    this.foregroundColor,
    this.cursorColor,
    this.tint,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.glassEffectUnionId,
    this.glassEffectId,
    this.border,
    this.autofocus = false,
    this.textInputAction,
    this.semanticLabel,
    this.counterText,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixIconColor,
    this.suffixIconColor,
    this.magnifierStyle,
    this.onPrefixIconTap,
    this.onSuffixIconTap,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.onCompleted,
    this.otpStyle = LiquidGlassOtpStyle.field,
  }) : assert(
         controller == null || text == null,
         'Provide either a controller or a text value, not both.',
       );

  @override
  State<LiquidGlassTextField> createState() => _LiquidGlassTextFieldState();
}

class _LiquidGlassTextFieldState extends State<LiquidGlassTextField>
    with
        LiquidGlassRouteSuppression,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  /// Keeps a focused field alive in lazy lists, like [EditableText]: when the
  /// keyboard opens, the Scaffold shrinks the viewport and a field near the
  /// bottom can fall outside the list's cache extent before it is scrolled
  /// back into view. Disposing it then would drop focus and close the
  /// keyboard.
  @override
  bool get wantKeepAlive => _keepAliveWhileFocused;

  /// Read by the keep-alive mixin from `initState`, before [_focusNode]
  /// exists, so focus is mirrored into a plain field.
  bool _keepAliveWhileFocused = false;

  // Tracks every currently-mounted LiquidGlassTextField's FocusNode so that,
  // when focus moves directly from one to another, we can tell native to
  // hand off responder status atomically instead of racing a 'blur' and a
  // 'focus' call across two independent platform-channel round trips (see
  // _handleFocusNodeChanged).
  static final Set<FocusNode> _liveFocusNodes = <FocusNode>{};

  MethodChannel? _nativeChannel;
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  String? _lastKnownNativeText;
  bool _lastKnownNativeFocusState = false;
  bool _hasFocus = false;
  int _lastConfigHash = 0;
  NativeLiquidGlassIconPayload? _prefixIconPayload;
  NativeLiquidGlassIconPayload? _suffixIconPayload;
  int _iconPayloadRequestId = 0;

  // Dynamic height from native
  double _nativeHeight = 0;
  bool _hasReceivedHeight = false;

  /// Revision of the config last sent to native. Native tags each size report
  /// with the revision its layout was computed for; a report for an older
  /// revision (e.g. measured with the error row still showing, arriving just
  /// after validation cleared it) is ignored rather than applied and cached
  /// as the new state's height.
  int _configRevision = 0;

  /// Must match `validationAnimation` in `LiquidGlassTextFieldView.swift`:
  /// when the error row appears or disappears, native animates it over the
  /// same time and curve while this box animates to the new height.
  static const Duration _validationAnimationDuration = Duration(
    milliseconds: 200,
  );

  /// Height changes before this time animate (validation); others, such as a
  /// multiline field growing while typing, apply immediately like native.
  DateTime _animateHeightUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// The error changed and the box should animate once native applies it.
  bool _pendingValidationResize = false;

  /// Last height the native side reported for a given config, kept across
  /// State lifetimes.
  ///
  /// A field in a lazy `ListView` is disposed once it scrolls past the cache
  /// extent and rebuilt with a fresh State when it scrolls back, which throws
  /// [_nativeHeight] away and puts the estimate back in force — the reason the
  /// label bleed reappears mid-scroll rather than only at startup. Remembering
  /// the measurement lets the rebuilt field start at the height it had, and it
  /// is still only a starting value: `onSizeChanged` corrects it either way.
  ///
  /// Keyed by [_computeConfigHash], so two fields configured the same share an
  /// entry, which is exactly when they are the same height.
  static final Map<int, double> _measuredHeights = <int, double>{};

  @override
  MethodChannel? get suppressionChannel => _nativeChannel;

  bool get _isEnabled => widget.enabled && !widget.readOnly;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController(text: widget.text);
    _controller.addListener(_handleControllerChanged);

    _ownsFocusNode = widget.focusNode == null;
    _focusNode =
        widget.focusNode ?? FocusNode(debugLabel: 'LiquidGlassTextField');
    _focusNode.addListener(_handleFocusNodeChanged);
    _liveFocusNodes.add(_focusNode);

    _prepareIconPayloads();
    WidgetsBinding.instance.addObserver(this);

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (_ownsController) _controller.dispose();
      _ownsController = widget.controller == null;
      _controller =
          widget.controller ?? TextEditingController(text: widget.text);
      _controller.addListener(_handleControllerChanged);
      _lastKnownNativeText = null;
      _syncTextToNative();
    } else if (widget.controller == null &&
        widget.text != oldWidget.text &&
        widget.text != _controller.text &&
        !_hasFocus) {
      _controller.text = widget.text ?? '';
    }

    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusNodeChanged);
      _liveFocusNodes.remove(_focusNode);
      if (_ownsFocusNode) _focusNode.dispose();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode =
          widget.focusNode ?? FocusNode(debugLabel: 'LiquidGlassTextField');
      _focusNode.addListener(_handleFocusNodeChanged);
      _liveFocusNodes.add(_focusNode);
    }

    if (oldWidget.errorText != widget.errorText) {
      // Resize once native has applied the new error (see
      // _syncPropsToNativeIfNeeded), so both sides start animating together.
      _pendingValidationResize = true;
    }

    if (oldWidget.prefixIcon != widget.prefixIcon ||
        oldWidget.suffixIcon != widget.suffixIcon) {
      _prepareIconPayloads();
    } else {
      _syncPropsToNativeIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
    _focusNode.removeListener(_handleFocusNodeChanged);
    _liveFocusNodes.remove(_focusNode);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  /// Default one-time code length when [LiquidGlassTextField.maxLength] isn't
  /// set.
  static const int _defaultOtpLength = 6;

  bool get _isOtp => widget.textFieldType == LiquidGlassTextFieldType.otp;

  int? get _effectiveMaxLength =>
      widget.maxLength ?? (_isOtp ? _defaultOtpLength : null);

  /// Text [LiquidGlassTextField.onCompleted] last fired for, so it fires once
  /// per completion rather than on every rebuild.
  String? _completedText;

  void _checkCompleted(String text) {
    final max = _effectiveMaxLength;
    if (max == null || text.length < max) {
      _completedText = null;
      return;
    }
    if (text == _completedText) return;
    _completedText = text;
    widget.onCompleted?.call(text);
  }

  void _handleControllerChanged() {
    _checkCompleted(_controller.text);
    final text = _controller.text;
    if (text == _lastKnownNativeText) return;
    _lastKnownNativeText = text;
    widget.onChanged?.call(text);
    _syncTextToNative();
  }

  // — Keyboard reveal —
  //
  // A plain [Focus] widget (unlike Flutter's own [EditableText]) doesn't get
  // scrolled into view when the keyboard opens, so the native field would
  // stay wherever it was laid out even if the keyboard covers it. This mirrors
  // EditableText's behavior: follow the keyboard frame by frame while it
  // animates, glide briefly when focus moves with the keyboard already open,
  // and only scroll as far as needed to keep [scrollPadding] free.

  static const Duration _revealDuration = Duration(milliseconds: 100);
  static const Curve _revealCurve = Curves.fastOutSlowIn;

  /// Bottom view inset seen on the last metrics change, in physical pixels.
  double _lastBottomViewInset = 0;

  /// Guards against queuing more than one reveal per frame.
  bool _revealScheduled = false;

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = View.of(context);
    final bottomViewInset = view.viewInsets.bottom;
    // The engine sends a metrics change on every frame of the keyboard
    // animation, so each reveal only has to cover a frame's worth of
    // movement. Animating them would stack a new curve every frame and leave
    // the field lagging behind the keyboard.
    if (bottomViewInset > _lastBottomViewInset && _focusNode.hasFocus) {
      _keepAboveKeyboard(
        keyboardTop:
            (view.physicalSize.height - bottomViewInset) /
            view.devicePixelRatio,
      );
      _revealAboveKeyboard(animate: false);
    }
    _lastBottomViewInset = bottomViewInset;
  }

  /// Scrolls immediately, before the frame that applies the new keyboard
  /// inset is laid out, so this field is already above [keyboardTop] in it.
  ///
  /// Revealing only after that frame (as [EditableText] can) is too late for
  /// a native field: the Scaffold shrinks the viewport in that frame, the
  /// field falls outside it and isn't painted, and a platform view that isn't
  /// painted is removed from the window, which resigns the native text field
  /// and closes the keyboard again.
  void _keepAboveKeyboard({required double keyboardTop}) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || !position.hasPixels) return;
    // The field's global position only updates at layout. When several
    // metrics changes arrive before the next frame, earlier jumps in this
    // frame are already applied to the scroll offset but not yet to the
    // field's position, so subtract them or the same overlap is counted twice.
    final fieldBottom =
        box.localToGlobal(Offset(0, box.size.height)).dy -
        _jumpSinceLayout +
        widget.scrollPadding.bottom;
    final overlap = fieldBottom - keyboardTop;
    if (overlap <= 0) return;
    position.jumpTo(position.pixels + overlap);
    if (_jumpSinceLayout == 0) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _jumpSinceLayout = 0,
      );
    }
    _jumpSinceLayout += overlap;
  }

  /// Scroll applied by [_keepAboveKeyboard] since the last layout.
  double _jumpSinceLayout = 0;

  /// Scrolls the nearest scrollable just enough to show this field, with
  /// [LiquidGlassTextField.scrollPadding] around it, above the keyboard.
  void _revealAboveKeyboard({required bool animate}) {
    if (_revealScheduled) return;
    _revealScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || !_focusNode.hasFocus) return;
      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;
      final rect = widget.scrollPadding.inflateRect(renderObject.paintBounds);
      if (animate) {
        renderObject.showOnScreen(
          rect: rect,
          duration: _revealDuration,
          curve: _revealCurve,
        );
      } else {
        renderObject.showOnScreen(rect: rect);
      }
    });
  }

  void _handleFocusNodeChanged() {
    _keepAliveWhileFocused = _focusNode.hasFocus;
    updateKeepAlive();
    // With the keyboard already open (focus moving between fields) no
    // metrics change will follow, so glide this field into view now. When
    // the keyboard is still closed, didChangeMetrics reveals it as it opens.
    if (_focusNode.hasFocus && View.of(context).viewInsets.bottom > 0) {
      _revealAboveKeyboard(animate: true);
    }

    final channel = _nativeChannel;
    if (channel == null) return;
    final wantsFocus = _focusNode.hasFocus;
    // Native already reported this exact state (or we already told it):
    // re-sending would nudge an already-focused SwiftUI @FocusState, which
    // can trigger a native resign/re-become blip and a feedback loop that
    // ends in a real, unwanted blur.
    if (wantsFocus == _lastKnownNativeFocusState) return;

    if (!wantsFocus) {
      final newPrimary = FocusManager.instance.primaryFocus;
      if (newPrimary != null && _liveFocusNodes.contains(newPrimary)) {
        // Focus is moving straight to another LiquidGlassTextField, not
        // away to nothing. That field's own 'focus' call will atomically
        // resign us via iOS's single-first-responder rule. Sending our own
        // 'blur' here would race it over a *separate* platform channel and
        // force a full keyboard dismiss-then-reshow instead of a smooth
        // handoff between fields.
        _lastKnownNativeFocusState = false;
        return;
      }
    }

    _lastKnownNativeFocusState = wantsFocus;
    channel.invokeMethod(wantsFocus ? 'focus' : 'blur');
  }

  Future<void> _prepareIconPayloads() async {
    final requestId = ++_iconPayloadRequestId;

    final prefixPayload =
        widget.prefixIcon != null && !widget.prefixIcon!.isSfSymbol
        ? await resolveIconPayload(widget.prefixIcon)
        : null;
    final suffixPayload =
        widget.suffixIcon != null && !widget.suffixIcon!.isSfSymbol
        ? await resolveIconPayload(widget.suffixIcon)
        : null;

    if (!mounted || requestId != _iconPayloadRequestId) return;

    setState(() {
      _prefixIconPayload = prefixPayload;
      _suffixIconPayload = suffixPayload;
    });
    _syncPropsToNativeIfNeeded();
  }

  Future<void> _syncTextToNative() async {
    final channel = _nativeChannel;
    if (channel == null) return;
    await channel.invokeMethod('setText', {'text': _controller.text});
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onChanged':
        final text = call.arguments as String? ?? '';
        if (mounted) {
          _lastKnownNativeText = text;
          if (_controller.text != text) {
            _controller.value = _controller.value.copyWith(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
              composing: TextRange.empty,
            );
          }
          widget.onChanged?.call(text);
          _checkCompleted(text);
        }
        break;
      case 'onFocusChange':
        final hasFocus = call.arguments as bool? ?? false;
        // Native is already in this state; don't let the FocusNode listener
        // echo it back as a redundant 'focus'/'blur' command (see
        // _handleFocusNodeChanged).
        _lastKnownNativeFocusState = hasFocus;
        if (mounted) {
          setState(() => _hasFocus = hasFocus);
          if (hasFocus && !_focusNode.hasFocus) {
            _focusNode.requestFocus();
          } else if (!hasFocus && _focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        }
        break;
      case 'onSubmitted':
        final text = call.arguments as String? ?? _controller.text;
        widget.onEditingComplete?.call();
        widget.onSubmitted?.call(text);
        break;
      case 'onPrefixIconTap':
        widget.onPrefixIconTap?.call();
        break;
      case 'onSuffixIconTap':
        widget.onSuffixIconTap?.call();
        break;
      case 'onSizeChanged':
        final args = call.arguments as Map<dynamic, dynamic>?;
        final reportedHeight = (args?['height'] as num?)?.toDouble() ?? 0;
        final revision = (args?['revision'] as num?)?.toInt();
        if (revision != null && revision < _configRevision) break;
        if (mounted && reportedHeight > 0) {
          // Never remember (or apply) less than the safe floor -- see
          // _estimatedFloorHeight for why a transient under-measurement
          // must not get to poison future recycles of this same config.
          final height = math.max(reportedHeight, _measuredFloorHeight());
          _measuredHeights[_computeConfigHash()] = height;
          if (height != _nativeHeight) {
            setState(() {
              _nativeHeight = height;
              _hasReceivedHeight = true;
            });
          }
        }
        break;
    }
  }

  void _onPlatformViewCreated(int viewId) {
    final channelName = 'liquid-glass-text-field-view/$viewId';
    final channel = MethodChannel(channelName);
    channel.setMethodCallHandler(_handleNativeMethodCall);
    _nativeChannel = channel;
    _lastConfigHash = _computeConfigHash();
    _lastKnownNativeText = _controller.text;
    _syncPropsToNativeIfNeeded();
    if (_focusNode.hasFocus) {
      _lastKnownNativeFocusState = true;
      channel.invokeMethod('focus');
    }
  }

  int _nativeTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return 1;
      case TextAlign.right:
      case TextAlign.end:
        return 2;
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        return 0;
    }
  }

  int _computeConfigHash() {
    return Object.hashAll([
      widget.hint,
      widget.label,
      widget.errorText,
      widget.counterText,
      widget.enabled,
      widget.readOnly,
      widget.obscureText,
      widget.textFieldType.name,
      widget.style.name,
      widget.width,
      widget.height,
      widget.borderRadius,
      widget.padding,
      textStyleSignature(widget.textStyle),
      textStyleSignature(widget.hintStyle),
      textStyleSignature(widget.labelStyle),
      widget.foregroundColor?.toARGB32(),
      widget.cursorColor?.toARGB32(),
      widget.tint?.toARGB32(),
      widget.textAlign,
      widget.textCapitalization,
      widget.autocorrect,
      widget.enableSuggestions,
      widget.maxLines,
      widget.minLines,
      widget.glassEffectUnionId,
      widget.glassEffectId,
      widget.border?.signature,
      widget.autofocus,
      widget.textInputAction?.index,
      widget.maxLength,
      widget.prefixIcon?.nativeSignature,
      widget.suffixIcon?.nativeSignature,
      widget.prefixIconColor?.toARGB32(),
      widget.suffixIconColor?.toARGB32(),
      widget.otpStyle,
    ]);
  }

  Map<String, Object?> _buildNativeCreationParams() {
    return {
      'revision': _configRevision,
      'text': _controller.text,
      'hint': widget.hint,
      'label': widget.label,
      'errorText': widget.errorText,
      if (widget.counterText != null) 'counterText': widget.counterText,
      'enabled': _isEnabled,
      'readOnly': widget.readOnly,
      'secureTextEntry':
          widget.obscureText ||
          widget.textFieldType == LiquidGlassTextFieldType.password,
      'inputType': widget.textFieldType.name,
      'style': widget.style.name,
      if (widget.width != null) 'width': widget.width,
      if (widget.height != null) 'height': widget.height,
      if (widget.borderRadius != null) 'borderRadius': widget.borderRadius,
      if (widget.padding != null) ...{
        'paddingTop': widget.padding!.top,
        'paddingBottom': widget.padding!.bottom,
        'paddingLeft': widget.padding!.left,
        'paddingRight': widget.padding!.right,
      },
      'textStyle': textStylePayload(widget.textStyle),
      'hintStyle': textStylePayload(widget.hintStyle),
      'labelStyle': textStylePayload(widget.labelStyle),
      if (widget.foregroundColor != null)
        'foregroundColor': widget.foregroundColor!.toARGB32(),
      if (widget.cursorColor != null)
        'cursorColor': widget.cursorColor!.toARGB32(),
      if (widget.tint != null) 'tint': widget.tint!.toARGB32(),
      'textAlign': _nativeTextAlign(widget.textAlign),
      'textCapitalization': widget.textCapitalization.name,
      'autocorrect': widget.autocorrect,
      'enableSuggestions': widget.enableSuggestions,
      'maxLines': _isMultiline ? (widget.maxLines ?? 0) : 1,
      if (widget.minLines != null && _isMultiline) 'minLines': widget.minLines,
      if (widget.glassEffectUnionId != null)
        'glassEffectUnionId': widget.glassEffectUnionId,
      if (widget.glassEffectId != null) 'glassEffectId': widget.glassEffectId,
      if (widget.border != null) ...widget.border!.toMap(),
      'autoFocus': widget.autofocus,
      if (widget.textInputAction != null)
        'textInputAction': widget.textInputAction!.name,
      if (_effectiveMaxLength != null) 'maxLength': _effectiveMaxLength,
      if (_isOtp) 'otpStyle': widget.otpStyle.name,
      if (widget.prefixIcon != null) ...{
        'prefixIcon': widget.prefixIcon!.toNativeMap(_prefixIconPayload),
        if (widget.prefixIconColor != null)
          'prefixIconColor': widget.prefixIconColor!.toARGB32(),
      },
      if (widget.suffixIcon != null) ...{
        'suffixIcon': widget.suffixIcon!.toNativeMap(_suffixIconPayload),
        if (widget.suffixIconColor != null)
          'suffixIconColor': widget.suffixIconColor!.toARGB32(),
      },
      if (widget.onPrefixIconTap != null) 'hasPrefixIconTap': true,
      if (widget.onSuffixIconTap != null) 'hasSuffixIconTap': true,
      if (widget.magnifierStyle != null)
        'magnifierStyle': widget.magnifierStyle!.name,
    };
  }

  Future<void> _syncPropsToNativeIfNeeded() async {
    final channel = _nativeChannel;
    if (channel == null) return;

    final hash = _computeConfigHash();
    if (_lastConfigHash != hash) {
      _configRevision++;
      await channel.invokeMethod('updateConfig', _buildNativeCreationParams());
      _lastConfigHash = hash;
      if (_pendingValidationResize && mounted) {
        // Native has the new error and starts its animation now: start this
        // box's resize in step with it, toward the remembered or estimated
        // height. Native's measured height then retargets the animation.
        _pendingValidationResize = false;
        setState(() {
          _hasReceivedHeight = false;
          _animateHeightUntil = DateTime.now().add(
            _validationAnimationDuration * 2,
          );
        });
      }
    }
  }

  // Estimate the native VStack for the *current* config.
  //
  // The old estimate counted the field box only, so a field with a label --
  // every field in the example's TextField preview -- reserved roughly 20px
  // less than the native view draws. The host container does not clip, so
  // the shortfall came out as the label painting over the Flutter section
  // header above it. [LiquidGlassTextFieldMetrics] counts every row the
  // native stack can hold, and this is also used as a floor in
  // [_handleNativeMethodCall]'s `onSizeChanged`: SwiftUI's `GeometryReader`
  // can report a smaller, transient size on its first layout pass before
  // settling on the real one, and if that transient value is the last one
  // received (e.g. a fast re-scroll disposes the field before the
  // follow-up correction arrives), it would otherwise get remembered as the
  // field's height and reproduce the same bleed on every later recycle.
  double _estimatedFloorHeight() {
    return LiquidGlassTextFieldMetrics.estimateHeight(
      hasLabel: widget.label != null && widget.label!.isNotEmpty,
      labelFontSize: widget.labelStyle?.fontSize,
      hasErrorText: widget.errorText != null && widget.errorText!.isNotEmpty,
      hasCounterText:
          widget.counterText != null && widget.counterText!.isNotEmpty,
      maxLines: widget.maxLines,
    );
  }

  /// The smallest measurement accepted from native. Same as the estimate,
  /// except a multi-line field may measure shorter than its `maxLines`
  /// upper bound (it grows from `minLines`), so only one line is assumed.
  double _measuredFloorHeight() {
    if (!_isMultiline) return _estimatedFloorHeight();
    return LiquidGlassTextFieldMetrics.estimateHeight(
      hasLabel: widget.label != null && widget.label!.isNotEmpty,
      labelFontSize: widget.labelStyle?.fontSize,
      hasErrorText: widget.errorText != null && widget.errorText!.isNotEmpty,
      hasCounterText:
          widget.counterText != null && widget.counterText!.isNotEmpty,
      fieldHeight: LiquidGlassTextFieldMetrics.multilineBaseHeight,
    );
  }

  bool get _isMultiline =>
      widget.textFieldType == LiquidGlassTextFieldType.multiline ||
      (widget.maxLines != null && widget.maxLines! > 1);

  double _getEffectiveHeight() {
    // Priority 1: Explicit height from widget
    if (widget.height != null) return widget.height!;

    // Priority 2: Height reported from native (dynamic content)
    if (_hasReceivedHeight && _nativeHeight > 0) return _nativeHeight;

    // Priority 3: The height native last reported for this same config, from
    // a previous State of an identically configured field. See
    // [_measuredHeights].
    final remembered = _measuredHeights[_computeConfigHash()];
    if (remembered != null && remembered > 0) return remembered;

    // Priority 4: Estimate the native VStack.
    return _estimatedFloorHeight();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    if (NativeLiquidGlassUtils.usesNativeViews) {
      final effectiveHeight = _getEffectiveHeight();

      final animate = DateTime.now().isBefore(_animateHeightUntil);
      return Focus(
        focusNode: _focusNode,
        canRequestFocus: _isEnabled,
        // Same widget type either way, so the platform view is never
        // recreated; only the duration differs.
        child: AnimatedContainer(
          duration: animate ? _validationAnimationDuration : Duration.zero,
          curve: Curves.easeOut,
          width: widget.width,
          height: effectiveHeight,
          child: UiKitView(
            viewType: 'liquid-glass-text-field-view',
            creationParams: _buildNativeCreationParams(),
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
            layoutDirection: TextDirection.ltr,
          ),
        ),
      );
    }
    return _buildFallbackTextField(context);
  }

  /// Flutter version of [LiquidGlassOtpStyle.boxes]: boxes over a transparent
  /// [TextField] that owns the keyboard and one-time-code autofill.
  Widget _buildFallbackOtpBoxes(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final length = _effectiveMaxLength ?? _defaultOtpLength;
    final active = widget.cursorColor ?? widget.tint ?? colorScheme.primary;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    const spacing = 8.0;
    // Same as native: boxes fill the width edge to edge (so the row is always
    // centered); they stop growing taller at 56.
    const maxBoxHeight = 56.0;
    final obscure =
        widget.obscureText ||
        widget.textFieldType == LiquidGlassTextFieldType.password;

    final boxes = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : length * 50 + (length - 1) * spacing;
        final boxWidth = math.max(
          28.0,
          (width - (length - 1) * spacing) / length,
        );
        final boxHeight = math.min(boxWidth, maxBoxHeight);
        return SizedBox(
          width: width,
          height: boxHeight,
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([_controller, _focusNode]),
                builder: (context, _) {
                  final code = _controller.text;
                  final activeIndex = code.length.clamp(0, length - 1);
                  return Row(
                    children: [
                      for (var i = 0; i < length; i++) ...[
                        if (i > 0) const SizedBox(width: spacing),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: boxWidth,
                          height: boxHeight,
                          alignment: Alignment.center,
                          decoration: _otpBoxDecoration(
                            colorScheme: colorScheme,
                            emphasized:
                                hasError ||
                                (_focusNode.hasFocus && i == activeIndex),
                            accent: hasError ? colorScheme.error : active,
                          ),
                          child: Text(
                            i < code.length ? (obscure ? '●' : code[i]) : '',
                            style: TextStyle(
                              fontSize: boxHeight * 0.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled && !widget.readOnly,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(length),
                    ],
                    onSubmitted: widget.onSubmitted,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: widget.labelStyle),
          const SizedBox(height: 4),
        ],
        boxes,
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style:
                widget.errorStyle ??
                TextStyle(color: colorScheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  /// Fallback box per [LiquidGlassTextField.style], matching native.
  BoxDecoration _otpBoxDecoration({
    required ColorScheme colorScheme,
    required bool emphasized,
    required Color accent,
  }) {
    final radius = BorderRadius.circular(widget.borderRadius ?? 14);
    final idle = colorScheme.outline.withValues(alpha: 0.4);
    switch (widget.style) {
      case LiquidGlassTextFieldStyle.underlined:
        return BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: emphasized ? accent : idle,
              width: emphasized ? 2 : 1,
            ),
          ),
        );
      case LiquidGlassTextFieldStyle.plain:
        return BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: emphasized ? accent : idle,
            width: emphasized ? 2 : 1,
          ),
        );
      case LiquidGlassTextFieldStyle.glass:
      case LiquidGlassTextFieldStyle.rounded:
        return BoxDecoration(
          color:
              widget.tint?.withValues(alpha: 0.15) ??
              colorScheme.surfaceContainerHighest,
          borderRadius: radius,
          border: Border.all(
            color: emphasized ? accent : Colors.transparent,
            width: 2,
          ),
        );
    }
  }

  Widget _buildFallbackTextField(BuildContext context) {
    if (_isOtp && widget.otpStyle == LiquidGlassOtpStyle.boxes) {
      return _buildFallbackOtpBoxes(context);
    }
    final effectiveStyle = widget.style == LiquidGlassTextFieldStyle.glass
        ? LiquidGlassTextFieldStyle.rounded
        : widget.style;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      enabled: widget.enabled && !widget.readOnly,
      readOnly: widget.readOnly,
      obscureText:
          widget.obscureText ||
          widget.textFieldType == LiquidGlassTextFieldType.password,
      maxLines: widget.textFieldType == LiquidGlassTextFieldType.multiline
          ? widget.maxLines ?? 1
          : 1,
      minLines: widget.minLines,
      style:
          widget.textStyle?.copyWith(color: widget.foregroundColor) ??
          (widget.foregroundColor != null
              ? TextStyle(color: widget.foregroundColor)
              : null),
      textAlign: widget.textAlign,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      cursorColor: widget.cursorColor,
      decoration: InputDecoration(
        hintText: widget.hint,
        labelText: widget.label,
        errorText: widget.errorText,
        counterText: widget.counterText,
        border: _getFallbackBorder(effectiveStyle),
        enabledBorder: _getFallbackBorder(effectiveStyle),
        focusedBorder: _getFallbackBorder(effectiveStyle),
        filled: effectiveStyle != LiquidGlassTextFieldStyle.underlined,
        fillColor: effectiveStyle == LiquidGlassTextFieldStyle.plain
            ? Colors.grey.withOpacity(0.1)
            : null,
        prefixIcon: widget.prefixIcon != null
            ? Icon(Icons.person, color: widget.prefixIconColor)
            : null,
        suffixIcon: widget.suffixIcon != null
            ? Icon(Icons.search, color: widget.suffixIconColor)
            : null,
      ),
      textInputAction: widget.textInputAction,
      maxLength: _effectiveMaxLength,
      keyboardType: _isOtp ? TextInputType.number : null,
      autofillHints: _isOtp ? const [AutofillHints.oneTimeCode] : null,
      inputFormatters: _isOtp ? [FilteringTextInputFormatter.digitsOnly] : null,
      scrollPadding: widget.scrollPadding,
      autofocus: false, // handled via _focusNode above
    );
  }

  InputBorder _getFallbackBorder(LiquidGlassTextFieldStyle style) {
    final borderRadius = widget.borderRadius ?? 8.0;
    switch (style) {
      case LiquidGlassTextFieldStyle.rounded:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        );
      case LiquidGlassTextFieldStyle.underlined:
        return const UnderlineInputBorder();
      case LiquidGlassTextFieldStyle.plain:
      case LiquidGlassTextFieldStyle.glass:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        );
    }
  }
}
