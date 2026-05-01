import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'utils/text_style_utils.dart';

/// Text input type for the native text field.
enum LiquidGlassTextFieldType {
  text,
  multiline,
  email,
  password,
  number,
  phone,
  url,
}

/// Magnifier style for text selection (iOS only)
enum LiquidGlassMagnifierStyle { standard, glass, minimal, elevated, compact }

/// Visual style for [LiquidGlassTextField].
enum LiquidGlassTextFieldStyle { plain, rounded, glass, underlined }

/// A native-styled Liquid Glass text field for iOS.
class LiquidGlassTextField extends StatefulWidget {
  final String? text;
  final ValueChanged<String>? onChanged;
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
  final Color? tint;
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

  const LiquidGlassTextField({
    super.key,
    this.text,
    this.onChanged,
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
    this.tint,
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
  });

  @override
  State<LiquidGlassTextField> createState() => _LiquidGlassTextFieldState();
}

class _LiquidGlassTextFieldState extends State<LiquidGlassTextField>
    with LiquidGlassRouteSuppression {
  MethodChannel? _nativeChannel;
  String? _currentText;
  bool _hasFocus = false;
  int _lastConfigHash = 0;
  NativeLiquidGlassIconPayload? _prefixIconPayload;
  NativeLiquidGlassIconPayload? _suffixIconPayload;
  int _iconPayloadRequestId = 0;
  
  // Dynamic height from native
  double _nativeHeight = 0;
  bool _hasReceivedHeight = false;

  @override
  MethodChannel? get suppressionChannel => _nativeChannel;

  bool get _isEnabled => widget.enabled && !widget.readOnly;

  @override
  void initState() {
    super.initState();
    _currentText = widget.text;
    _prepareIconPayloads();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _currentText && !_hasFocus) {
      _currentText = widget.text;
      _syncTextToNative();
    }
    if (oldWidget.prefixIcon != widget.prefixIcon ||
        oldWidget.suffixIcon != widget.suffixIcon) {
      _prepareIconPayloads();
    } else {
      _syncPropsToNativeIfNeeded();
    }
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
    await channel.invokeMethod('setText', {'text': _currentText ?? ''});
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onChanged':
        final text = call.arguments as String? ?? '';
        if (mounted) {
          setState(() => _currentText = text);
          widget.onChanged?.call(text);
        }
        break;
      case 'onFocusChange':
        final hasFocus = call.arguments as bool? ?? false;
        if (mounted) setState(() => _hasFocus = hasFocus);
        break;
      case 'onSubmitted':
        break;
      case 'onPrefixIconTap':
        widget.onPrefixIconTap?.call();
        break;
      case 'onSuffixIconTap':
        widget.onSuffixIconTap?.call();
        break;
      case 'requestFocus':
        if (mounted) _requestFocus();
        break;
      case 'onSizeChanged':
        final args = call.arguments as Map<dynamic, dynamic>?;
        final height = (args?['height'] as double?) ?? 0;
        if (mounted && height > 0 && height != _nativeHeight) {
          setState(() {
            _nativeHeight = height;
            _hasReceivedHeight = true;
          });
        }
        break;
    }
  }

  void _requestFocus() {
    _nativeChannel?.invokeMethod('focus', null);
  }

  void _onPlatformViewCreated(int viewId) {
    final channelName = 'liquid-glass-text-field-view/$viewId';
    final channel = MethodChannel(channelName);
    channel.setMethodCallHandler(_handleNativeMethodCall);
    _nativeChannel = channel;
    _lastConfigHash = _computeConfigHash();
    _syncPropsToNativeIfNeeded();
    _syncTextToNative();
    if (widget.autofocus) {
      Future.delayed(const Duration(milliseconds: 100), _requestFocus);
    }
  }

  int _computeConfigHash() {
    return Object.hashAll([
      widget.hint,
      widget.label,
      widget.errorText,
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
      widget.tint?.toARGB32(),
      widget.maxLines,
      widget.minLines,
      widget.glassEffectUnionId,
      widget.glassEffectId,
      widget.border?.signature,
      widget.textInputAction?.index,
      widget.maxLength,
      widget.prefixIcon?.nativeSignature,
      widget.suffixIcon?.nativeSignature,
      widget.prefixIconColor?.toARGB32(),
      widget.suffixIconColor?.toARGB32(),
    ]);
  }

  Map<String, Object?> _buildNativeCreationParams() {
    final isMultiline =
        widget.textFieldType == LiquidGlassTextFieldType.multiline ||
        (widget.maxLines != null && widget.maxLines! > 1);

    return {
      'text': _currentText ?? '',
      'hint': widget.hint,
      'label': widget.label,
      'errorText': widget.errorText,
      'enabled': _isEnabled,
      'readOnly': widget.readOnly,
      'secureTextEntry':
          widget.obscureText ||
          widget.textFieldType == LiquidGlassTextFieldType.password,
      'textFieldType': widget.textFieldType.name,
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
      if (widget.tint != null) 'tint': widget.tint!.toARGB32(),
      'maxLines': isMultiline ? (widget.maxLines ?? 0) : 1,
      if (widget.minLines != null && isMultiline) 'minLines': widget.minLines,
      if (widget.glassEffectUnionId != null)
        'glassEffectUnionId': widget.glassEffectUnionId,
      if (widget.glassEffectId != null) 'glassEffectId': widget.glassEffectId,
      if (widget.border != null) ...widget.border!.toMap(),
      if (widget.textInputAction != null)
        'textInputAction': widget.textInputAction!.name,
      if (widget.maxLength != null) 'maxLength': widget.maxLength,
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
      await channel.invokeMethod('updateConfig', _buildNativeCreationParams());
      _lastConfigHash = hash;
    }
  }

  double _getEffectiveHeight() {
    // Priority 1: Explicit height from widget
    if (widget.height != null) return widget.height!;
    
    // Priority 2: Height reported from native (dynamic content)
    if (_hasReceivedHeight && _nativeHeight > 0) return _nativeHeight;
    
    // Priority 3: Estimate based on maxLines
    if (widget.maxLines != null && widget.maxLines! > 1) {
      // Base height: label (20) + padding + (lines * lineHeight)
      return 44.0 + (widget.maxLines! - 1) * 24.0;
    }
    
    // Priority 4: Default height
    return 50.0;
  }

  @override
  Widget build(BuildContext context) {
    if (NativeLiquidGlassUtils.supportsLiquidGlass) {
      final effectiveHeight = _getEffectiveHeight();
      
      return SizedBox(
        width: widget.width,
        height: effectiveHeight,
        child: UiKitView(
          viewType: 'liquid-glass-text-field-view',
          creationParams: _buildNativeCreationParams(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          layoutDirection: TextDirection.ltr,
        ),
      );
    }
    return _buildFallbackTextField(context);
  }

  Widget _buildFallbackTextField(BuildContext context) {
    final effectiveStyle = widget.style == LiquidGlassTextFieldStyle.glass
        ? LiquidGlassTextFieldStyle.rounded
        : widget.style;

    return TextField(
      controller: TextEditingController(text: _currentText)
        ..addListener(() {
          final newText = _currentText;
          if (mounted && newText != widget.text) {
            widget.onChanged?.call(newText ?? '');
          }
        }),
      onChanged: widget.onChanged,
      enabled: widget.enabled && !widget.readOnly,
      readOnly: widget.readOnly,
      obscureText:
          widget.obscureText ||
          widget.textFieldType == LiquidGlassTextFieldType.password,
      maxLines: widget.textFieldType == LiquidGlassTextFieldType.multiline
          ? widget.maxLines ?? 1
          : 1,
      minLines: widget.minLines,
      style: widget.textStyle,
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
      maxLength: widget.maxLength,
      autofocus: widget.autofocus,
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