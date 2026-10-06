import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/farmora_logo.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPw = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMsg = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMsg = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await AuthService.instance.register(email: email, password: password);

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: FarmoraColors.inkSoft,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmoraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              title: 'Create account',
              subtitle: 'Join Farmora in a few seconds',
              leading: FarmoraLogo(size: 34, radius: 6),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _label('Email address'),
                  CustomTextField(
                    placeholder: 'you@farmora.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _label('Password'),
                  CustomTextField(
                    placeholder: 'At least 6 characters',
                    controller: _passwordCtrl,
                    isPassword: true,
                    obscureText: !_showPw,
                    onTogglePassword: () => setState(() => _showPw = !_showPw),
                  ),
                  const SizedBox(height: 16),
                  _label('Confirm password'),
                  CustomTextField(
                    placeholder: 'Re-enter your password',
                    controller: _confirmCtrl,
                    isPassword: true,
                    obscureText: !_showConfirm,
                    onTogglePassword: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMsg!,
                      style: TextStyle(
                        color: FarmoraColors.crit,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  PrimaryButton(
                    text: _loading ? 'Creating account…' : 'Create account',
                    disabled: _loading,
                    onClick: _loading ? () {} : _submit,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(
                            fontSize: 12.5, color: FarmoraColors.inkSoft),
                      ),
                      TextButton(
                        onPressed:
                            _loading ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your credentials are protected by end-to-end encrypted transport.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: FarmoraColors.inkFaint,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
