import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

class LiquidGlassTextFieldPreviewPage extends StatefulWidget {
  final Function(bool)? onThemeChanged;

  const LiquidGlassTextFieldPreviewPage({super.key, this.onThemeChanged});

  @override
  State<LiquidGlassTextFieldPreviewPage> createState() =>
      _LiquidGlassTextFieldPreviewPageState();
}

class _LiquidGlassTextFieldPreviewPageState
    extends State<LiquidGlassTextFieldPreviewPage> {
  // State variables
  String _name = '';
  String _email = '';
  String _password = '';
  String _bio = '';
  String _phone = '';
  String _searchQuery = '';
  String? _emailError;
  String? _passwordError;

  // Password visibility
  bool _obscurePassword = true;

  // controller / focusNode parity demo
  late final TextEditingController _firstNameController =
      TextEditingController();
  late final FocusNode _firstNameFocusNode = FocusNode();
  late final TextEditingController _lastNameController =
      TextEditingController();
  final FocusNode _lastNameFocusNode = FocusNode();
  String _lastSubmitted = '';

  @override
  void dispose() {
    _firstNameController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameController.dispose();
    _lastNameFocusNode.dispose();
    super.dispose();
  }

  void _validateEmail(String email) {
    setState(() {
      _email = email;
      if (email.isEmpty) {
        _emailError = null;
      } else if (!email.contains('@') || !email.contains('.')) {
        _emailError = 'Please enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String password) {
    setState(() {
      _password = password;
      if (password.isEmpty) {
        _passwordError = null;
      } else if (password.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else {
        _passwordError = null;
      }
    });
  }

  void _submitForm() {
    if (_emailError == null &&
        _passwordError == null &&
        _email.isNotEmpty &&
        _password.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix all errors before submitting'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearAll() {
    setState(() {
      _name = '';
      _email = '';
      _password = '';
      _bio = '';
      _phone = '';
      _searchQuery = '';
      _emailError = null;
      _passwordError = null;
      _obscurePassword = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All fields cleared'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liquid Glass TextField'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          if (widget.onThemeChanged != null)
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => widget.onThemeChanged!(!isDarkMode),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [Colors.grey.shade900, Colors.black]
                : [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liquid Glass TextField',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Native iOS text input with Liquid Glass effect',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Basic Input Fields Section
            _buildSectionHeader('Basic Input Fields'),
            const SizedBox(height: 16),

            // Name Field
            LiquidGlassTextField(
              hint: 'Enter your full name',
              label: 'Full Name',
              text: _name,
              onChanged: (value) => setState(() => _name = value),
              style: LiquidGlassTextFieldStyle.glass,
              tint: Colors.blue,
              prefixIcon: NativeLiquidGlassIcon.sfSymbol('person.fill'),
            ),
            // Email Field
            LiquidGlassTextField(
              hint: 'you@example.com',
              label: 'Email Address',
              textFieldType: LiquidGlassTextFieldType.email,
              text: _email,
              onChanged: _validateEmail,
              errorText: _emailError,
              prefixIcon: NativeLiquidGlassIcon.sfSymbol('envelope.fill'),
              style: LiquidGlassTextFieldStyle.glass,
              tint: Colors.blue,
            ),

            // Password Field
            LiquidGlassTextField(
              hint: 'Enter your password',
              label: 'Password',
              obscureText: _obscurePassword,
              text: _password,
              onChanged: _validatePassword,
              errorText: _passwordError,
              prefixIcon: NativeLiquidGlassIcon.sfSymbol('lock.fill'),
              suffixIcon: NativeLiquidGlassIcon.sfSymbol(
                _obscurePassword ? 'eye.slash.fill' : 'eye.fill',
              ),
              onSuffixIconTap: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              magnifierStyle: LiquidGlassMagnifierStyle.standard,
              style: LiquidGlassTextFieldStyle.glass,
              tint: Colors.blue,
            ),
            const SizedBox(height: 32),

            // TextField-parity Section (controller / focusNode / onSubmitted)
            _buildSectionHeader('Flutter TextField Parity'),
            const SizedBox(height: 16),

            LiquidGlassTextField(
              controller: _firstNameController,
              focusNode: _firstNameFocusNode,
              hint: 'First name',
              label: 'First Name (controller)',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _lastNameFocusNode.requestFocus(),
              tint: Colors.indigo,
            ),
            const SizedBox(height: 20),

            LiquidGlassTextField(
              controller: _lastNameController,
              focusNode: _lastNameFocusNode,
              hint: 'Last name',
              label: 'Last Name (focusNode chained)',
              textCapitalization: TextCapitalization.words,
              textAlign: TextAlign.center,
              cursorColor: Colors.indigo,
              textInputAction: TextInputAction.done,
              onEditingComplete: () =>
                  setState(() => _lastSubmitted = _lastNameController.text),
              onSubmitted: (value) =>
                  setState(() => _lastSubmitted = value),
              tint: Colors.indigo,
            ),
            if (_lastSubmitted.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Submitted: $_lastSubmitted'),
            ],
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Focus First Name',
                    onPressed: () => _firstNameFocusNode.requestFocus(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Clear via controller',
                    onPressed: () {
                      _firstNameController.clear();
                      _lastNameController.clear();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Specialized Inputs Section
            _buildSectionHeader('Specialized Input Types'),
            const SizedBox(height: 16),

            // Phone Field
            LiquidGlassTextField(
              hint: '(555) 123-4567',
              label: 'Phone Number',
              textFieldType: LiquidGlassTextFieldType.phone,
              text: _phone,
              onChanged: (value) => setState(() => _phone = value),
              prefixIcon: NativeLiquidGlassIcon.sfSymbol('phone.fill'),
              style: LiquidGlassTextFieldStyle.glass,
              tint: Colors.green,
              maxLength: 15,
            ),
            const SizedBox(height: 20),

            // Search Field
            LiquidGlassTextField(
              hint: 'Search...',
              label: 'Search',
              text: _searchQuery,
              onChanged: (value) => setState(() => _searchQuery = value),
              prefixIcon: NativeLiquidGlassIcon.sfSymbol('magnifyingglass'),
              suffixIcon: NativeLiquidGlassIcon.sfSymbol('mic.fill'),
              style: LiquidGlassTextFieldStyle.glass,
              tint: Colors.purple,
            ),
            const SizedBox(height: 20),

            // Bio Field (Multiline)
            LiquidGlassTextField(
              hint: 'Tell us about yourself...',
              label: 'Bio',
              text: _bio,
              onChanged: (value) => setState(() => _bio = value),
              textFieldType: LiquidGlassTextFieldType.multiline,
              maxLines: 4,
              minLines: 3,
              style: LiquidGlassTextFieldStyle.glass,
              counterText: '${_bio.length}/200',
              maxLength: 200,
              tint: Colors.orange,
            ),
            const SizedBox(height: 32),

            // Style Variations Section
            _buildSectionHeader('Style Variations'),
            const SizedBox(height: 16),

            // Plain Style
            LiquidGlassTextField(
              hint: 'Plain style input',
              label: 'Plain Field',
              style: LiquidGlassTextFieldStyle.plain,
              tint: Colors.orange,
              prefixIcon: NativeLiquidGlassIcon.sfSymbol('doc.text.fill'),
            ),
            const SizedBox(height: 20),

            // Underlined Style
            LiquidGlassTextField(
              hint: 'Underlined style input',
              label: 'Underlined Field',
              style: LiquidGlassTextFieldStyle.underlined,
              tint: Colors.teal,
              prefixIcon: NativeLiquidGlassIcon.sfSymbol('underline'),
            ),
            const SizedBox(height: 20),

            // Rounded Style
            LiquidGlassTextField(
              hint: 'Rounded with custom tint',
              label: 'Rounded Field',
              style: LiquidGlassTextFieldStyle.rounded,
              tint: Colors.pink,
              prefixIcon: NativeLiquidGlassIcon.sfSymbol('star.fill'),
            ),
            const SizedBox(height: 32),

            // Field States Section
            _buildSectionHeader('Field States'),
            const SizedBox(height: 16),

            // Read-only field
            LiquidGlassTextField(
              label: 'User ID (Read-only)',
              text: 'USER_12345',
              readOnly: true,
              enabled: true,
              style: LiquidGlassTextFieldStyle.glass,
              prefixIcon:
                  NativeLiquidGlassIcon.sfSymbol('person.badge.key.fill'),
              tint: Colors.grey,
            ),
            const SizedBox(height: 20),

            // Disabled field
            LiquidGlassTextField(
              label: 'Disabled Field',
              hint: 'This field is disabled',
              text: 'Cannot edit this',
              enabled: false,
              style: LiquidGlassTextFieldStyle.glass,
            ),
            const SizedBox(height: 32),

            // Form Actions
            Row(
              children: [
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Submit Form',
                    onPressed: _submitForm,
                    style: LiquidGlassButtonStyle.prominentGlass,
                    tint: Colors.blue,
                    icon: NativeLiquidGlassIcon.sfSymbol('checkmark.circle.fill'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Clear All',
                    onPressed: _clearAll,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Display entered information
            if (_name.isNotEmpty ||
                _email.isNotEmpty ||
                _phone.isNotEmpty ||
                _bio.isNotEmpty ||
                _searchQuery.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [Colors.grey.shade800, Colors.grey.shade900]
                        : [Colors.grey.shade100, Colors.grey.shade50],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Entered Information:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_name.isNotEmpty) _buildInfoRow(Icons.person, 'Name', _name),
                    if (_email.isNotEmpty) _buildInfoRow(Icons.email, 'Email', _email),
                    if (_phone.isNotEmpty) _buildInfoRow(Icons.phone, 'Phone', _phone),
                    if (_bio.isNotEmpty) _buildInfoRow(Icons.description, 'Bio', _bio),
                    if (_searchQuery.isNotEmpty)
                      _buildInfoRow(Icons.search, 'Search', _searchQuery),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.purple],
              ),
              borderRadius: BorderRadius.zero,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}