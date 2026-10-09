import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../widgets/theme_mode_action_button.dart';

class LiquidGlassOtpPreviewPage extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;

  const LiquidGlassOtpPreviewPage({super.key, required this.onThemeChanged});

  @override
  State<LiquidGlassOtpPreviewPage> createState() =>
      _LiquidGlassOtpPreviewPageState();
}

class _LiquidGlassOtpPreviewPageState extends State<LiquidGlassOtpPreviewPage> {
  /// The demo accepts this code; anything else shows the error state.
  static const String _correctCode = '123456';

  final _boxesController = TextEditingController();
  bool _boxesError = false;
  bool _obscure = false;
  LiquidGlassTextFieldStyle _boxStyle = LiquidGlassTextFieldStyle.plain;
  String _boxesStatus = 'Enter the 6-digit code (try $_correctCode)';
  String _fieldStatus = 'Waiting for code';

  @override
  void dispose() {
    _boxesController.dispose();
    super.dispose();
  }

  void _verify(String code) {
    final ok = code == _correctCode;
    setState(() {
      _boxesError = !ok;
      _boxesStatus = ok ? 'Verified ✓' : 'Enter the code again';
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP preview'),
        actions: [ThemeModeActionButton(onThemeChanged: widget.onThemeChanged)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Glass boxes', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'LiquidGlassTextField with textFieldType: otp and otpStyle: '
            'boxes — one glass box per digit. The code from Messages appears '
            'above the keyboard and fills every box.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          LiquidGlassTextField(
            key: const ValueKey('otpBoxes'),
            controller: _boxesController,
            label: 'Verification code',
            textFieldType: LiquidGlassTextFieldType.otp,
            otpStyle: LiquidGlassOtpStyle.boxes,
            style: _boxStyle,
            obscureText: _obscure,
            errorText: _boxesError ? 'Wrong code, try again' : null,
            onChanged: (code) {
              if (_boxesError && code.length < 6) {
                setState(() {
                  _boxesError = false;
                  _boxesStatus = 'Enter the 6-digit code';
                });
              }
            },
            onCompleted: _verify,
          ),
          const SizedBox(height: 12),
          Center(child: Text(_boxesStatus)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  _boxesController.clear();
                  setState(() {
                    _boxesError = false;
                    _boxesStatus = 'Enter the 6-digit code';
                  });
                },
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => _boxesController.text = _correctCode,
                child: const Text('Fill from code'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // The boxes follow the field's `style`; only `glass` uses Liquid
          // Glass.
          SegmentedButton<LiquidGlassTextFieldStyle>(
            segments: const [
              ButtonSegment(
                value: LiquidGlassTextFieldStyle.glass,
                label: Text('Glass'),
              ),
              ButtonSegment(
                value: LiquidGlassTextFieldStyle.rounded,
                label: Text('Rounded'),
              ),
              ButtonSegment(
                value: LiquidGlassTextFieldStyle.plain,
                label: Text('Plain'),
              ),
              ButtonSegment(
                value: LiquidGlassTextFieldStyle.underlined,
                label: Text('Line'),
              ),
            ],
            selected: {_boxStyle},
            onSelectionChanged: (s) => setState(() => _boxStyle = s.first),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide digits'),
            value: _obscure,
            onChanged: (v) => setState(() => _obscure = v),
          ),
          const Divider(height: 40),
          Text('Single text field', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'LiquidGlassTextField with textFieldType: otp (otpStyle: field) — number pad, '
            'digits only, code autofill, onCompleted at 6 digits.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          LiquidGlassTextField(
            label: 'Verification code',
            hint: '6-digit code',
            textFieldType: LiquidGlassTextFieldType.otp,
            onChanged: (_) => setState(() => _fieldStatus = 'Typing…'),
            onCompleted: (code) =>
                setState(() => _fieldStatus = 'Completed: $code'),
          ),
          const SizedBox(height: 12),
          Text(_fieldStatus),
        ],
      ),
    );
  }
}
